// GATE ADVERSARIAL independente do delta `5f6d3be..ebd040c` da F2b (setes-app, branch f2b — commit ebd040c "Gates do delta
// 60df1df..5f6d3be: D-F216 nas três portas, relógio do aparelho, D-F218…D-F220"), lado CORE:
//   - D-F216 nas TRÊS portas do envelope (`envelopeData` / `envelopePage` / envelope ESTRITO do `_send`) com `service` obrigatório;
//   - D-F219: `jwtExpiry` + `AuthBloc._unusableToken` (CLIENT_CLOCK) — token recém-emitido que o relógio do aparelho já dá por vencido;
//   - D-F220: a query de qualquer URL dentro da causa sai antes do `debugPrint`;
//   - login: token "" / seleção sem estabelecimentos.
// O gate anterior (`apps/web/test/adversarial_le_gate_test.dart`) já cobre: o login em 21 formas, as 10 leituras do core contra as rotas
// reais, a matriz D-F214, o fuzz da D-F217, o `isClosed`, as formas reais da exceção de rede (`uri=`) e os dois DECIDIDOS D-F219/D-F220
// no caminho feliz. ESTE arquivo ataca o que ficou de fora: a MATRIZ do `exp` (tipos, unidades, limites), o INVARIANTE "AuthAuthenticated ⇒
// a guarda aceita" para 30+ formas de token, o diagnóstico do CLIENT_CLOCK (falso positivo com o TTL do servidor quebrado), as três portas
// com corpos hostis (e que o corpo NUNCA vai ao console), e as variantes de causa da D-F220 (esquema em maiúsculas, sem esquema, URL entre
// aspas, várias URLs, `?` no meio do texto).
//
// Convenção (a mesma dos gates anteriores):
//   - `[ACHADO LF-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para ver
//     a falha:   flutter test --run-skipped test/adversarial_lf_core_test.dart
//   - `[FATO LF-ADV-NN]` = o comportamento atual registrado (roda sempre).
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada fala com servidor: o `ApiClient`/`NfseApiClient`/`AuthBloc` DE VERDADE sobre o `MockClient`.

import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
// ignore: implementation_imports
import 'package:core/src/auth/presentation/content/auth_feedback.dart' show isTechnicalFailure;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'https://api.setes.example';
const _nfseBase = 'https://nfse.setes.example';
const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
const _invalid = ClientFailureCodes.invalidResponse;

http.Response _r(String body, [int status = 200]) => http.Response(body, status, headers: _jsonHeaders);

String _seg(Object? o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

/// JWT na forma que o setes-api assina (`jsonwebtoken` RS256: `iat` + `exp` em SEGUNDOS, mais a identidade).
String _jwtWith(Map<String, Object?> payload) => '${_seg({'alg': 'RS256', 'typ': 'JWT', 'kid': 'k1'})}.${_seg(payload)}.assinatura';

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _jwt({Object? exp = _absent, int? iat}) => _jwtWith({
      'institutionId': 1,
      'userId': 1,
      'role': 'admin',
      'schemaName': 'setes_a',
      if (iat != null) 'iat': iat,
      if (!identical(exp, _absent)) 'exp': exp,
    });

const Object _absent = Object();

class _Prefs extends LocalPrefs {
  String? saved;
  bool keep = false;
  int? defaultInstitution;
  @override
  Future<bool> getKeepConnected() async => keep;
  @override
  Future<void> setKeepConnected(bool value) async => keep = value;
  @override
  Future<String?> getSessionToken() async => saved;
  @override
  Future<void> setSessionToken(String? token) async => saved = token;
  @override
  Future<String?> getRememberedEmail() async => null;
  @override
  Future<void> setRememberedEmail(String? email) async {}
  @override
  Future<int?> getDefaultInstitutionId() async => defaultInstitution;
  @override
  Future<void> setDefaultInstitutionId(int? institutionId) async => defaultInstitution = institutionId;
}

typedef _Route = Future<http.Response> Function(http.Request req);

class _Rig {
  _Rig(Map<String, _Route> routes) {
    api = ApiClient(
      client: MockClient((req) async {
        final route = routes[req.url.path];
        return route == null ? _r('{"error":"rota inexistente no rig"}', 404) : route(req);
      }),
      baseUrl: _base,
      session: session,
    );
    final repo = AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api));
    bloc = AuthBloc(
      loginUsecase: LoginUsecase(repository: repo),
      selectUsecase: SelectInstitutionUsecase(repository: repo),
      recoveryUsecase: RecoveryPasswordUsecase(repository: repo),
      changePasswordUsecase: ChangePasswordUsecase(repository: repo),
      apiClient: api,
      localPrefs: prefs,
    );
    sub = bloc.stream.listen(states.add);
  }

  final session = ProductToken();
  final prefs = _Prefs();
  late final ApiClient api;
  late final AuthBloc bloc;
  late final StreamSubscription<AuthState> sub;
  final states = <AuthState>[];

  Future<void> add(AuthEvent e) async {
    bloc.add(e);
    await pumpEventQueue(times: 60);
  }

  Future<void> close() async {
    await sub.cancel();
    await bloc.close();
  }
}

_Route _ok(String body) => (_) async => _r(body);

const _institutions = '[{"institutionId":1,"schemaName":"setes_a","name":"Empresa A","profile":"admin"},'
    '{"institutionId":2,"schemaName":"setes_b","name":"Empresa B","profile":"regular"}]';

/// Captura o `debugPrint` (o console do navegador) durante [body].
Future<List<String>> _console(Future<void> Function() body) async {
  final saved = debugPrint;
  final logs = <String>[];
  debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = saved;
  }
  return logs;
}

Future<Failure?> _failure(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } on Failure catch (f) {
    return f;
  }
}

void main() {
  // ---------------------------------------------------------------------------------------------------------------------------------
  // 1. `jwtExpiry` — a matriz do `exp` e da forma do token
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(1) jwtExpiry × isJwtExpired', () {
    test('[RESISTIU] a MATRIZ do `exp` (tipo, unidade, limite): nunca lança; `null` só quando não é um inteiro-número legível; `isJwtExpired` '
        'concorda com `jwtExpiry` em TODAS (null ⇒ vencido; senão `agora ≥ exp`)', () {
      final now = _nowSec();
      final cases = <String, (Object?, int?)>{
        'inteiro futuro': (now + 3600, now + 3600),
        'inteiro passado': (now - 3600, now - 3600),
        'zero': (0, 0),
        'negativo': (-5, -5),
        'double inteiro (1760000000.0)': ((now + 3600).toDouble(), now + 3600),
        'double fracionário (trunca)': (now + 3600.9, now + 3600),
        'texto numérico': ('${now + 3600}', null),
        'texto vazio': ('', null),
        'booleano': (true, null),
        'lista': ([now + 3600], null),
        'objeto': ({'v': now + 3600}, null),
        'nulo explícito': (null, null),
      };
      for (final MapEntry(key: name, value: (exp, want)) in cases.entries) {
        final token = _jwt(exp: exp);
        late int? got;
        expect(() => got = jwtExpiry(token), returnsNormally, reason: name);
        expect(got, want, reason: name);
        expect(isJwtExpired(token), want == null ? true : now >= want, reason: 'isJwtExpired × $name');
      }
      // `exp` AUSENTE do payload (a chave nem existe)
      expect(jwtExpiry(_jwt()), isNull);
      expect(isJwtExpired(_jwt()), isTrue);
    });

    test('[RESISTIU] `exp` em MILISSEGUNDOS (um signer fora do contrato): é lido como segundos — o token vale "para sempre" no cliente, a guarda '
        'e o D-F219 aceitam, mas o servidor (que confere o `exp` em segundos) é quem manda: 401 e a sessão expira (nunca um login mudo)', () {
      final ms = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      expect(isJwtExpired(_jwt(exp: ms)), isFalse);
      expect(jwtExpiry(_jwt(exp: ms)), ms);
    });

    test('[RESISTIU] a FORMA do token: vazio, 1/2/4 partes, segmentos vazios, base64 inválido, payload que não é objeto, alfabeto base64 PADRÃO '
        '(+ /), espaços e quebra de linha nas bordas — nunca lança e é "vencido" (`null`)', () {
      final now = _nowSec();
      final good = _jwt(exp: now + 3600);
      final parts = good.split('.');
      // payload cujo base64 PADRÃO tem `+` e `/` (bytes 0xFB 0xFF…): não é o alfabeto URL-safe do JWT
      final stdAlphabet = '${parts[0]}.${base64.encode([0xFB, 0xFF, 0xBE, 0xFB, 0xFF]).replaceAll('=', '')}.sig';
      final forms = <String, String>{
        'vazio': '',
        'uma parte': 'abc',
        'duas partes': 'a.b',
        'quatro partes': '$good.extra',
        'segmentos vazios': '..',
        'payload vazio': '${parts[0]}..sig',
        'payload base64 inválido': '${parts[0]}.!!!.sig',
        'payload é array': '${parts[0]}.${_seg([now + 3600])}.sig',
        'payload é string': '${parts[0]}.${_seg('x')}.sig',
        'payload é null': '${parts[0]}.${_seg(null)}.sig',
        'payload não-JSON': '${parts[0]}.${base64Url.encode(utf8.encode('isto nao e json')).replaceAll('=', '')}.sig',
        'alfabeto base64 padrão': stdAlphabet,
        'só espaços': '   ',
        'ponto sozinho': '.',
        'dois pontos': '..',
      };
      for (final MapEntry(key: name, value: token) in forms.entries) {
        late int? got;
        expect(() => got = jwtExpiry(token), returnsNormally, reason: name);
        expect(got, isNull, reason: name);
        expect(isJwtExpired(token), isTrue, reason: name);
      }
      // O que ainda é lido: padding `=` presente, espaço/quebra de linha ao redor do TOKEN INTEIRO só afeta o 1º/3º segmento
      final padded = parts[1] + '=' * ((4 - parts[1].length % 4) % 4);
      expect(jwtExpiry('${parts[0]}.$padded.${parts[2]}'), now + 3600, reason: 'padding presente');
      expect(jwtExpiry('${parts[0]}.${parts[1]}.sig\n'), now + 3600, reason: 'quebra de linha depois da assinatura');
      expect(jwtExpiry(' ${parts[0]}.${parts[1]}.sig'), now + 3600, reason: 'espaço ANTES do cabeçalho: só o 2º segmento é decodificado');
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 2. D-F219 — o INVARIANTE "AuthAuthenticated ⇒ a guarda aceita" e o que o login grava
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(2) D-F219 × AuthBloc', () {
    Future<_Rig> login(String token, {bool keep = false}) async {
      final rig = _Rig({'/auth/login': _ok(jsonEncode({'ok': true, 'token': token, 'context': <String, Object?>{}}))});
      await rig.add(AuthLoginRequested(email: 'a@b.c', password: 'x', keepConnected: keep));
      return rig;
    }

    test('[RESISTIU] o INVARIANTE nas 30 formas de token (login E seleção, "manter conectado" ligado): se o estado final é `AuthAuthenticated`, '
        'então a guarda (`!isJwtExpired`) aceita o MESMO token e a sessão foi gravada (memória + dispositivo); se não, é erro TÉCNICO '
        '(`CLIENT_INVALID_RESPONSE` | `CLIENT_CLOCK`), NADA foi gravado e o spinner não ficou', () async {
      final now = _nowSec();
      final tokens = <String, String>{
        for (final k in [-86400, -3600, -60, -1, 0, 3, 60, 3600, 86400]) 'exp ${k >= 0 ? '+' : ''}$k s': _jwt(exp: now + k, iat: now),
        'sem exp': _jwt(iat: now),
        'exp texto': _jwt(exp: '${now + 3600}'),
        'exp nulo': _jwt(exp: null),
        'exp zero': _jwt(exp: 0),
        'exp negativo': _jwt(exp: -1),
        'exp ms': _jwt(exp: now * 1000),
        'exp double': _jwt(exp: (now + 3600).toDouble()),
        'exp 1e30 (double)': _jwt(exp: 1e30),
        'exp 2^53': _jwt(exp: 9007199254740992),
        'exp 1e19': _jwt(exp: 1e19),
        'exp texto vazio': _jwt(exp: ''),
        'exp booleano': _jwt(exp: true),
        'exp lista': _jwt(exp: [now + 3600]),
        'cabeçalho vazio': '.${_seg({'exp': now + 3600})}.sig',
        'duas partes': '${_seg({'alg': 'RS256'})}.${_seg({'exp': now + 3600})}',
        'não-JWT': 'nao-e-um-jwt',
        'só espaços': '   ',
        'quatro partes': '${_jwt(exp: now + 3600)}.x',
        'payload array': '${_seg({'alg': 'RS256'})}.${_seg([1])}.sig',
        'payload string': '${_seg({'alg': 'RS256'})}.${_seg('x')}.sig',
        'ponto': '.',
        'dois pontos': '..',
        'base64 inválido': '${_seg({'alg': 'RS256'})}.@@@.sig',
      };
      expect(tokens.length, greaterThanOrEqualTo(30));
      for (final MapEntry(key: name, value: token) in tokens.entries) {
        for (final viaSelection in [false, true]) {
          final rig = viaSelection
              ? _Rig({
                  '/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":$_institutions}'),
                  '/auth/select-institution': _ok(jsonEncode({'ok': true, 'token': token})),
                })
              : _Rig({'/auth/login': _ok(jsonEncode({'ok': true, 'token': token}))});
          await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x', keepConnected: true));
          if (viaSelection) {
            expect(rig.states.last, isA<AuthNeedsSelection>(), reason: '$name (seleção)');
            await rig.add(const AuthInstitutionSelected(institutionId: 1, setAsDefault: false));
          }
          final last = rig.states.last;
          final why = '$name ${viaSelection ? '(via seleção)' : '(direto)'}';
          expect(last, isNot(isA<AuthLoading>()), reason: 'spinner preso — $why');
          if (last is AuthAuthenticated) {
            expect(isJwtExpired(token), isFalse, reason: 'autenticou um token que a guarda RECUSA — $why');
            expect([rig.session.value, rig.prefs.saved], [token, token], reason: why);
          } else {
            final failure = (last as AuthError).failure;
            expect([failure.code, isTechnicalFailure(failure)], [anyOf(_invalid, ClientFailureCodes.clock), true], reason: why);
            expect([rig.session.value, rig.prefs.saved, rig.states.whereType<AuthAuthenticated>().length], [null, null, 0], reason: why);
            expect(isJwtExpired(token), isTrue, reason: 'recusou um token que a guarda aceitaria — $why');
          }
          await rig.close();
        }
      }
    });

    test('[RESISTIU] a fronteira: `exp = agora + 3 s` entra e `exp ≤ agora` é `CLIENT_CLOCK` (o `>=` da guarda); com `exp` legível mas já '
        'passado o código é CLOCK, com `exp` ilegível é INVALID_RESPONSE (nunca o contrário)', () async {
      final now = _nowSec();
      final inside = await login(_jwt(exp: now + 3, iat: now));
      expect(inside.states.last, isA<AuthAuthenticated>());
      await inside.close();
      // o `iat` é a hora do SERVIDOR: aparelho 1 dia adiantado ⇒ `agora − iat` longe de zero ⇒ o relógio é o suspeito (LF-ADV-01)
      for (final exp in [now, now - 1, now - 86400 * 365]) {
        final rig = await login(_jwt(exp: exp, iat: now - 2 * 86400));
        expect((rig.states.last as AuthError).failure.code, ClientFailureCodes.clock, reason: 'exp=$exp');
        await rig.close();
      }
      // sem `iat` legível não há como acusar o servidor: segue o aviso do relógio
      final noIat = await login(_jwt(exp: now - 1));
      expect((noIat.states.last as AuthError).failure.code, ClientFailureCodes.clock);
      await noIat.close();
      final unreadable = await login(_jwt(exp: 'amanhã'));
      expect((unreadable.states.last as AuthError).failure.code, _invalid);
      await unreadable.close();
    });

    test('[RESISTIU] o relógio ATRASADO (o `iat` do token no futuro do aparelho) não é erro: só o `exp` decide — o servidor é quem confere o `nbf`/`iat`',
        () async {
      final now = _nowSec();
      final rig = await login(_jwt(iat: now + 6 * 3600, exp: now + 6 * 3600 + 86400));
      expect(rig.states.last, isA<AuthAuthenticated>());
      await rig.close();
    });

    test('[RESISTIU] o relógio ADIANTADO com o TTL REAL de 24 h (setes-api `FINAL_TOKEN_TTL`): 23h59 de adiantamento entra, 24h+ é CLOCK '
        '(o diálogo é do aparelho)', () async {
      final now = _nowSec();
      // aparelho adiantado em D ⇒ para o aparelho o token emitido AGORA (pelo servidor) vence em `86400 − D`
      for (final (ahead, ok) in [(86400 - 120, true), (86400 - 10, true), (86400, false), (86400 + 1, false), (3 * 86400, false)]) {
        // o servidor emitiu na hora DELE (`now − ahead` no relógio do aparelho) com o TTL de 24 h
        final rig = await login(_jwt(iat: now - ahead, exp: now - ahead + 86400));
        expect(rig.states.last is AuthAuthenticated, ok, reason: 'adiantado ${ahead}s');
        if (!ok) expect((rig.states.last as AuthError).failure.code, ClientFailureCodes.clock, reason: 'adiantado ${ahead}s');
        await rig.close();
      }
    });

    test('[RESISTIU] o login com "manter conectado" desligado nunca grava o token no dispositivo, e o `CLIENT_CLOCK` não troca a sessão que '
        'JÁ existia no ProductToken (login recusado ≠ logout)', () async {
      final now = _nowSec();
      final rig = _Rig({'/auth/login': _ok(jsonEncode({'ok': true, 'token': _jwt(exp: now - 10)}))});
      rig.session.value = 'sessao-anterior';
      await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      expect(rig.session.value, 'sessao-anterior');
      expect(rig.prefs.saved, isNull);
      await rig.close();
    });

    test('[CORRIGIDO LF-ADV-01] o token que já NASCEU vencido no SERVIDOR (`iat == exp`, ex.: um `FINAL_TOKEN_TTL` mal configurado como "24", que '
        'o jsonwebtoken lê como 24 MILISSEGUNDOS) com o aparelho na hora CERTA (`|agora − iat|` ≤ 5 min) é RESPOSTA ILEGÍVEL do servidor — '
        'não "confira a data e a hora"; um `iat` longe do relógio segue sendo o aviso do relógio',
        () async {
      final now = _nowSec();
      final bornExpired = await login(_jwt(iat: now, exp: now)); // jsonwebtoken: expiresIn '24' ⇒ exp = floor(iat + 0,024) = iat
      final failure = (bornExpired.states.last as AuthError).failure;
      expect(failure.code, _invalid);
      expect(failure.supportRef, 'INVALID_RESPONSE · setes-api');
      await bornExpired.close();
      // a fronteira dos 5 min: dentro = servidor; fora = relógio do aparelho
      final inside = await login(_jwt(iat: now - 290, exp: now - 1));
      expect((inside.states.last as AuthError).failure.code, _invalid);
      await inside.close();
      final outside = await login(_jwt(iat: now - 310, exp: now - 1));
      expect((outside.states.last as AuthError).failure.code, ClientFailureCodes.clock);
      await outside.close();
    });

    test('[CORRIGIDO LF-ADV-02] o `supportRef` do CLOCK leva `agora`, `iat` e `exp` em UTC (sufixo Z) — o suporte compara com o relógio do '
        'servidor sem adivinhar o fuso; sem `iat` legível o campo some', () async {
      final now = _nowSec();
      final rig = await login(_jwt(iat: now - 2 * 86400, exp: now - 5));
      final ref = (rig.states.last as AuthError).failure.supportRef!;
      expect(ref, matches(RegExp(r'^CLOCK · agora=\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z iat=\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z exp=\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z$')));
      await rig.close();
      final noIat = await login(_jwt(exp: now - 5));
      expect((noIat.states.last as AuthError).failure.supportRef!, matches(RegExp(r'^CLOCK · agora=\S+Z exp=\S+Z$')));
      await noIat.close();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 3. login — token vazio e seleção sem estabelecimentos (a regra do LD-ADV-01) × formas que o gate anterior não montou
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(3) login × token vazio / seleção vazia', () {
    Future<String> describe(String body) async {
      final rig = _Rig({'/auth/login': _ok(body)});
      await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      final s = rig.states.last;
      await rig.close();
      return switch (s) {
        AuthAuthenticated() => 'autenticado',
        AuthNeedsSelection(:final session) => 'seleção(${session.institutions.length})',
        AuthError(:final failure) => 'erro ${failure.code}/${failure.supportRef}',
        _ => '$s',
      };
    }

    test('[RESISTIU] token "" / só espaços / seleção "" / `select` como texto / `select:true` com token e sem selectionToken / seleção com '
        '`institutions` null, objeto ou itens nulos: nunca "autenticado" sem sessão, nunca spinner', () async {
      final now = _nowSec();
      final good = _jwt(exp: now + 3600);
      final cases = <String, String>{
        'token vazio': '{"ok":true,"token":""}',
        'token só espaços (cai no D-F219)': '{"ok":true,"token":"   "}',
        'selectionToken vazio com lista': '{"ok":true,"select":true,"selectionToken":"","institutions":$_institutions}',
        'selectionToken nulo com lista': '{"ok":true,"select":true,"selectionToken":null,"institutions":$_institutions}',
        '`select` como texto + token': '{"ok":true,"select":"true","token":"$good"}',
        '`select:true` com token e sem selectionToken': '{"ok":true,"select":true,"token":"$good","institutions":$_institutions}',
        'institutions nulo': '{"ok":true,"select":true,"selectionToken":"sel","institutions":null}',
        'institutions é objeto': '{"ok":true,"select":true,"selectionToken":"sel","institutions":{"a":1}}',
        'institutions com item nulo': '{"ok":true,"select":true,"selectionToken":"sel","institutions":[null]}',
        'institutions com item texto': '{"ok":true,"select":true,"selectionToken":"sel","institutions":["x"]}',
        'institutions vazio': '{"ok":true,"select":true,"selectionToken":"sel","institutions":[]}',
        'token numérico': '{"ok":true,"token":12345}',
        'token objeto': '{"ok":true,"token":{"v":"$good"}}',
      };
      final got = <String, String>{for (final e in cases.entries) e.key: await describe(e.value)};
      expect(got, {
        'token vazio': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'token só espaços (cai no D-F219)': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'selectionToken vazio com lista': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'selectionToken nulo com lista': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        '`select` como texto + token': 'autenticado',   // `select != true` ⇒ lê o `token`: a forma antiga/neutra do contrato
        '`select:true` com token e sem selectionToken': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'institutions nulo': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'institutions é objeto': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'institutions com item nulo': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'institutions com item texto': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'institutions vazio': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'token numérico': 'erro $_invalid/INVALID_RESPONSE · setes-api',
        'token objeto': 'erro $_invalid/INVALID_RESPONSE · setes-api',
      });
    });

    test('[FATO LF-ADV-03] a "lista" da seleção é conferida só por TAMANHO: `institutions:[{}]` (item sem `institutionId`/`name`) vira UMA linha '
        'em branco com id 0 — o operador a toca e o `select-institution` volta 4xx de negócio. Só um servidor fora do contrato manda isso '
        '(o setes-api sempre preenche os 4 campos — auth.service.ts); limite conhecido, não achado', () async {
      final rig = _Rig({'/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":[{}]}')});
      await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      final s = rig.states.last as AuthNeedsSelection;
      expect([s.session.institutions.single.institutionId, s.session.institutions.single.name], [0, '']);
      await rig.close();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 3b. D-F216 — as leituras do core exigem o `ok`, não o `data`
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(3b) leituras do core × `{ok:true}` sem `data`', () {
    test('[FATO LF-ADV-10] o `envelopeOk` da D-F216 exige SÓ o `ok:true`: um 200 `{"ok":true}` (ou `data:null`) sem o `data` entra como sucesso VAZIO '
        'nas quatro leituras — menu vazio, preferências vazias, tema vazio e usuário 0 / "" — exatamente o efeito que a decisão queria evitar '
        'para o HTML do proxy. LOW: nenhum proxy fabrica `ok:true` (o HTML/array/`{}` são recusados — provado no gate anterior) e as rotas '
        'reais sempre levam o `data`; só um bug do SERVIDOR chega aqui. (a) se o Valdo quiser fechar: exigir `data` do tipo certo em cada leitor',
        () async {
      for (final body in ['{"ok":true}', '{"ok":true,"data":null}']) {
        final api = ApiClient(client: MockClient((_) async => _r(body)), baseUrl: _base);
        final menus = await MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: api)).getMenus();
        final me = await AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).getMe();
        expect(menus.isRight(), isTrue, reason: body);
        expect(me.fold((l) => null, (r) => r.userId), 0, reason: body);
      }
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 4. D-F216 — as TRÊS portas do envelope com corpos hostis (e o corpo nunca vai ao console)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(4) D-F216 × três portas × corpos hostis', () {
    const secret = 'SEGREDO-12345678909';

    // corpo → (aceito por envelopeData?, aceito por envelopePage?)
    final bodies = <String, (String, bool, bool)>{
      'HTML do proxy': ('<html><body>Plesk $secret</body></html>', false, false),
      'array JSON': ('["$secret"]', false, false),
      'null JSON': ('null', false, false),
      'string JSON': ('"$secret"', false, false),
      'vazio': ('', false, false),
      'objeto vazio': ('{}', false, false),
      'ok:false': ('{"ok":false,"error":"$secret"}', false, false),
      'ok:false com o código do cliente': ('{"ok":false,"code":"CLIENT_CLOCK","error":"$secret"}', false, false),
      'ok como texto': ('{"ok":"true","data":{}}', false, false),
      'ok como número': ('{"ok":1,"data":{}}', false, false),
      'ok sem data': ('{"ok":true}', false, false),
      'data nulo': ('{"ok":true,"data":null}', false, false),
      'data texto': ('{"ok":true,"data":"$secret"}', false, false),
      'data número': ('{"ok":true,"data":7}', false, false),
      'data lista (objeto esperado)': ('{"ok":true,"data":[]}', false, true),
      'data objeto (lista esperada)': ('{"ok":true,"data":{}}', true, false),
      'data objeto com o segredo': ('{"ok":true,"data":{"cpf":"$secret"}}', true, false),
      'data lista com o segredo': ('{"ok":true,"data":["$secret"],"total":-5,"page":0}', false, true),
    };

    Future<Failure?> through(ProductApiClient client, String path, String port) =>
        _failure(() async => port == 'data'
            ? envelopeData(await client.get(path), service: client.serviceLabel)
            : envelopePage(await client.get(path), service: client.serviceLabel));

    test('[RESISTIU] 18 corpos × (envelopeData | envelopePage) × (setes-api | nfse-api): ou o corpo é o certo e entra, ou é `CLIENT_INVALID_RESPONSE` '
        'com `INVALID_RESPONSE · <serviço do cliente>` — o serviço sempre o de QUEM respondeu — e o corpo (com o CPF) nunca aparece no '
        'console nem na falha', () async {
      final seen = <String>[];
      final logs = await _console(() async {
        for (final MapEntry(key: name, value: (body, dataOk, pageOk)) in bodies.entries) {
          for (final (label, mk) in <(String, ProductApiClient Function(String))>[
            ('setes-api', (b) => ApiClient(client: MockClient((_) async => _r(b)), baseUrl: _base)),
            ('nfse-api', (b) => NfseApiClient(client: MockClient((_) async => _r(b)), baseUrl: _nfseBase)),
          ]) {
            for (final port in ['data', 'page']) {
              final f = await through(mk(body), '/api/x?document=$secret', port);
              final accepted = port == 'data' ? dataOk : pageOk;
              final why = '$name · $label · $port';
              // o cliente ESTRITO (nfse-api) recusa antes de chegar à porta tudo que não é `{ok:true,…}`; o do setes-api tolera
              if (accepted) {
                expect(f, isNull, reason: why);
              } else {
                expect(f, isNotNull, reason: why);
                expect([f!.code, f.supportRef], [_invalid, 'INVALID_RESPONSE · $label'], reason: why);
                expect(f.message, 'core.errors.invalidResponse', reason: why);
                expect(f.toString(), isNot(contains(secret)), reason: why);
                expect(f.supportRef, isNot(contains(secret)), reason: why);
                seen.add(why);
              }
            }
          }
        }
      });
      expect(seen.length, greaterThan(40));
      expect(logs.where((l) => l.contains(secret)), isEmpty, reason: 'o corpo da resposta (ou a query) foi ao console');
      expect(logs.every((l) => l.startsWith('[ApiClient]')), isTrue);
    });

    test('[RESISTIU] o cliente ESTRITO e os status: 2xx/3xx fora do envelope = falha técnica com o status; 204 e corpo vazio idem; 4xx/5xx '
        'com HTML NÃO viram INVALID_RESPONSE (são a falha do status); o `ok:true` com 4xx continua sendo o erro do status', () async {
      for (final status in [200, 201, 202, 203, 204, 206, 301, 302, 304]) {
        final f = await _failure(() => NfseApiClient(client: MockClient((_) async => http.Response('<html>x</html>', status)), baseUrl: _nfseBase).get('/v1/x'));
        expect([f!.code, f.statusCode, f.supportRef], [_invalid, status, 'INVALID_RESPONSE · nfse-api'], reason: 'status $status');
      }
      for (final status in [400, 404, 422, 500, 502, 504]) {
        final f = await _failure(() => NfseApiClient(client: MockClient((_) async => http.Response('<html>x</html>', status)), baseUrl: _nfseBase).get('/v1/x'));
        expect([f!.code, f.statusCode], [isNot(_invalid), status], reason: 'status $status');
      }
      final okWith4xx = await _failure(() => NfseApiClient(client: MockClient((_) async => _r('{"ok":true,"data":{}}', 409)), baseUrl: _nfseBase).get('/v1/x'));
      expect(okWith4xx!.statusCode, 409);
    });

    test('[RESISTIU] o motivo no console das três portas é SEMPRE texto fixo + o status + o caminho SEM query (nenhum valor do corpo, da query '
        'nem do cabeçalho Authorization)', () async {
      final logs = await _console(() async {
        final api = ApiClient(client: MockClient((_) async => _r('[]')), baseUrl: _base, session: ProductToken()..value = 'JWT-SECRETO-ABC');
        final nfse = NfseApiClient(client: MockClient((_) async => _r('<html>$secret</html>')), baseUrl: _nfseBase, session: ProductToken()..value = 'JWT-SECRETO-ABC');
        await _failure(() async => envelopeData(await api.get('/api/a?document=$secret'), service: 'setes-api'));
        await _failure(() async => envelopePage(await api.get('/api/b?document=$secret'), service: 'setes-api'));
        await _failure(() => nfse.get('/v1/c?document=$secret'));
        await _failure(() async => envelopeOk(await api.get('/api/d?document=$secret'), service: 'setes-api'));
      });
      expect(logs.length, 4);
      expect(logs.join('\n'), allOf(isNot(contains(secret)), isNot(contains('JWT-SECRETO')), isNot(contains('document='))));
      expect(logs[2], '[ApiClient] resposta ilegível de nfse-api: 200 fora do envelope { ok: true } em /v1/c');
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 5. D-F220 — a query de qualquer URL dentro da causa
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(5) D-F220 × formas da causa', () {
    const doc = '12345678909';

    Future<String> consoleOf(Object Function(Uri) boom, {String path = '/api/entities/by-document?personType=F&document=$doc'}) async {
      final logs = await _console(() async {
        final api = ApiClient(client: MockClient((req) async => throw boom(req.url)), baseUrl: _base);
        await expectLater(api.get(path), throwsA(isA<NetworkFailure>()));
      });
      expect(logs.length, 1);
      return logs.single;
    }

    test('[RESISTIU] a URL na causa em 14 formas que um `Uri` do Dart/navegador PRODUZ: entre aspas simples/duplas/parênteses/colchetes, no '
        'fim, no meio, depois de vírgula/ponto e vírgula/dois-pontos, repetida 3 vezes, IPv6, com porta, com userinfo, com `#fragmento`, '
        'com query vazia (`?`), com query percent-encoded e a MESMA url no `uri=` — o documento NUNCA chega ao console; o caminho e a causa ficam',
        () async {
      final forms = <String, String Function(String)>{
        'aspas simples': (u) => "Failed to fetch '$u' from origin",
        'aspas duplas': (u) => 'Failed to fetch "$u" from origin',
        'parênteses': (u) => 'TypeError (url: $u)',
        'colchetes': (u) => 'blocked [$u] by CORS',
        'no fim': (u) => 'Cross-Origin Request Blocked: $u',
        'depois de vírgula': (u) => 'Failed, $u, retry',
        'depois de ponto e vírgula': (u) => 'Failed;$u;retry',
        'depois de dois-pontos': (u) => 'Failed:$u',
        'repetida 3×': (u) => 'a $u b $u c $u',
        'com porta': (u) => 'x ${u.replaceFirst('.example', '.example:8443')}',
        'IPv6': (u) => 'x ${u.replaceFirst('api.setes.example', '[::1]:3000')}',
        'userinfo': (u) => 'x ${u.replaceFirst('https://', 'https://user:pw@')}',
        'com fragmento DEPOIS': (u) => 'x $u#frag',
        'a mesma url no uri=': (u) => 'Failed to fetch, uri=$u',
      };
      for (final MapEntry(key: name, value: make) in forms.entries) {
        final line = await consoleOf((uri) => http.ClientException(make(uri.toString()), uri));
        expect(line, allOf(isNot(contains(doc)), isNot(contains('document=')), isNot(contains('personType'))), reason: name);
        expect(line, contains('falha de rede em setes-api /api/entities/by-document'), reason: name);
      }
      // a query vazia e a codificada
      final empty = await consoleOf((u) => http.ClientException('x ${u.replace(query: '')}', u), path: '/api/x?document=$doc');
      expect(empty, isNot(contains(doc)));
      final encoded = await consoleOf((u) => http.ClientException('x $u', u), path: '/api/customers?filter=Jo%C3%A3o%20Silva%20$doc&criteria=%7B%22d%22%3A%22$doc%22%7D');
      expect(encoded, allOf(isNot(contains(doc)), isNot(contains('criteria'))));
    });

    test('[RESISTIU] a causa que NÃO é URL é preservada inteira (certificado, DNS, recusa, tempo) — o regex não come texto inocente com `?`',
        () async {
      final causes = [
        'Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate(handshake.cc:393))',
        "Failed host lookup: 'api.setes.example' (OS Error: No address associated with hostname, errno = 7)",
        'Connection refused (OS Error: Connection refused, errno = 111), address = 10.0.0.5, port = 3000',
        'TimeoutException after 0:00:30.000000: Future not completed',
        'Pergunta? talvez: sim; a causa tem ? e # e & e = soltos',
        'sem esquema https mas com ?query-solta=1',
      ];
      for (final cause in causes) {
        final line = await consoleOf((_) => Exception(cause));
        expect(line, contains(cause.replaceAll(RegExp(r',?\s*uri=\S*'), '')), reason: cause);
      }
    });

    test('[CORRIGIDO LF-ADV-04 em parte — gates do delta 5f6d3be..ebd040c] o regex da D-F220 passou a entender QUALQUER esquema em QUALQUER '
        'caixa (`HTTPS://`, `wss://`); segue como CONHECIMENTO NEGATIVO a URL SEM esquema (`//host/p?q`, `host/p?q`, `/caminho?q`): LOW e '
        'TEÓRICO — o `Uri` do Dart normaliza o esquema e as mensagens do navegador citam a URL na forma do `Uri` (com `uri=` — que o primeiro '
        'regex tira); o dia em que uma causa citar a URL por outro caminho, esta lista é a que falha', () async {
      final leaks = <String, String>{};
      for (final MapEntry(key: name, value: text) in {
        'esquema em maiúsculas': 'x HTTPS://api.setes.example/api/x?document=$doc',
        'sem esquema (//)': 'x //api.setes.example/api/x?document=$doc',
        'host/caminho': 'x api.setes.example/api/x?document=$doc',
        'caminho': 'x /api/x?document=$doc',
        'wss': 'x wss://api.setes.example/api/x?document=$doc',
      }.entries) {
        final line = await consoleOf((_) => Exception(text));
        if (line.contains(doc)) leaks[name] = line;
      }
      expect(leaks.keys.toSet(), {'sem esquema (//)', 'host/caminho', 'caminho'});
    });

    test('[RESISTIU] custo do regex em causas de até 5 mil caracteres (espaços, `http://` repetido, `uri=` repetido, `?` repetido, URL longa sem '
        '`?`): limpa em < 1,5 s no total — a causa real de uma exceção de rede tem < 1 KB. [FATO LF-ADV-05, LOW teórico, analisado + medido '
        'na VM] o primeiro regex (o do `uri=`, da D-F215) é QUADRÁTICO numa corrida de espaços (20 mil espaços ≈ 1,1 s; 100 mil ≈ 25 s) — só uma causa '
        'de dezenas de KB de espaços travaria o catch da rede; nenhum caminho do app põe texto do servidor na causa', () async {
      final watch = Stopwatch()..start();
      for (final cause in [
        ' ' * 5000,
        'http://' * 700,
        'uri=' * 1250,
        'a?' * 2500,
        'http://x/${'a' * 5000}',
      ]) {
        await consoleOf((_) => Exception(cause));
      }
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1500)));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
