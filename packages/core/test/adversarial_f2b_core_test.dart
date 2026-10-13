// GATE ADVERSARIAL da F2b (setes-app como cliente direto da nfse-api) — o
// núcleo HTTP do app: ProductToken (um token para N APIs, 401 global — D-F138)
// e ApiClient × NfseApiClient (D-F4/D-F146). Convenção do gate:
//   - `[ACHADO F2B-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_f2b_core_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: MockClient do package:http.

import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// Página do host do app (fallback de SPA do Plesk) — o que volta quando a
/// `NFSE_API_URL` aponta para o lugar errado mas na MESMA origem.
http.Response _spaIndex() => http.Response(
    '<!DOCTYPE html><html><head><title>Setes ERP</title></head><body></body></html>', 200,
    headers: {'content-type': 'text/html'});

// Achados CORRIGIDOS na sessão (os testes rodam sempre): ADV-04 (envelope estrito na nfse-api), ADV-06 (D-F148 = Q-F160 (a): o 401 de
// quem não emitiu o token só expira depois de o EMISSOR confirmar), ADV-10 (URL normalizada; base torta = erro de CONFIGURAÇÃO),
// ADV-11 (ouvintes isolados), ADV-16 (`/auth/*` sem o Bearer da sessão).

void main() {
  group('F2B-ADV-04 — 2xx que NÃO é o envelope da casa', () {
    test('[CORRIGIDO F2B-ADV-04 MEDIUM] 200 com HTML (fallback de SPA) é FALHA técnica — antes voltava {} como sucesso',
        () async {
      final nfse = NfseApiClient(client: MockClient((_) async => _spaIndex()), baseUrl: 'https://erp.setes.com.br');
      // certo: corpo 2xx que não é `{ ok: true, ... }` é falha técnica (nunca
      // "sucesso vazio" — os datasources transformam {} em "não transmitida",
      // "nada pendente" e "autorizada")
      await expectLater(nfse.get('/v1/nfse/invoices/pending?interfaceKey=service-orders'),
          throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.invalidResponse)));
    });

    test('[CORRIGIDO F2B-ADV-04 MEDIUM] 302 num POST (proxy/SSO) é FALHA — antes o transmit "dava certo" com {}',
        () async {
      final nfse = NfseApiClient(
          client: MockClient((_) async => http.Response('', 302, headers: {'location': '/login'})),
          baseUrl: 'https://nfse');
      await expectLater(nfse.post('/v1/nfse/invoices/1/transmit', const {}), throwsA(isA<Failure>()));
    });

    test('[RESISTIU] o setes-api segue tolerante (rotas antigas fora do envelope) — só a nfse-api é estrita', () async {
      final erp = ApiClient(client: MockClient((_) async => _json(200, {'status': 'ok'})), baseUrl: 'http://erp');
      expect(await erp.get('/health'), {'status': 'ok'});
    });

    test('[RESISTIU] 5xx com HTML (proxy) vira Failure com o status — nunca FormatException', () async {
      final nfse = NfseApiClient(
          client: MockClient((_) async => http.Response('<html>504 Gateway Time-out</html>', 504)),
          baseUrl: 'https://nfse');
      await expectLater(
          nfse.post('/v1/nfse/invoices/1/transmit', const {}),
          throwsA(isA<Failure>()
              .having((f) => f.statusCode, 'statusCode', 504)
              .having((f) => f.code, 'code', isNull)));
    });
  });

  group('401 global (D-F138)', () {
    test('[RESISTIU] 401 ATRASADO da nfse-api (token velho) depois do relogin pelo setes-api não derruba a sessão nova',
        () async {
      final session = ProductToken()..value = 'T1';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final erp = ApiClient(client: MockClient((_) async => _json(200, {'ok': true})), baseUrl: 'http://erp', session: session);
      final nfse = NfseApiClient(
          client: MockClient((_) async {
            erp.token = 'T2'; // relogin enquanto a requisição da nfse-api estava no ar
            return _json(401, {'error': 'Token expirado', 'code': 'UNAUTHORIZED'});
          }),
          baseUrl: 'http://nfse',
          session: session);
      await expectLater(nfse.get('/v1/nfse/invoices/1'), throwsA(isA<UnauthorizedFailure>()));
      expect([expired, session.value], [0, 'T2']);
    });

    test('[RESISTIU] dois 401 SIMULTÂNEOS da mesma sessão (as duas APIs) expiram UMA vez', () async {
      final session = ProductToken()..value = 'T1';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      MockClient dead() => MockClient((_) async => _json(401, {'error': 'Token inválido', 'code': 'UNAUTHORIZED'}));
      final erp = ApiClient(client: dead(), baseUrl: 'http://erp', session: session);
      final nfse = NfseApiClient(client: dead(), baseUrl: 'http://nfse', session: session);
      final results = await Future.wait([
        erp.get('/api/core/me').then((_) => 'ok', onError: (Object e) => e.runtimeType.toString()),
        nfse.get('/v1/nfse/invoices/1').then((_) => 'ok', onError: (Object e) => e.runtimeType.toString()),
      ]);
      expect(results, ['UnauthorizedFailure', 'UnauthorizedFailure']);
      expect(expired, 1);
    });

    test('[RESISTIU] ouvinte que se remove DURANTE a notificação não quebra a lista (cópia antes de iterar)', () {
      final session = ProductToken()..value = 'T';
      late void Function() remove;
      var second = 0;
      remove = session.addExpiredListener(() => remove());
      session.addExpiredListener(() => second++);
      session.expire('T');
      expect(second, 1);
    });

    test('[CORRIGIDO F2B-ADV-11 LOW] ouvinte que LANÇA não cala os demais nem troca o UnauthorizedFailure', () async {
      final session = ProductToken()..value = 'T';
      var second = 0;
      session.addExpiredListener(() => throw StateError('LocalPrefs indisponível'));
      session.addExpiredListener(() => second++);
      final erp = ApiClient(
          client: MockClient((_) async => _json(401, {'error': 'Token expirado', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://erp',
          session: session);
      // a requisição continua sendo UnauthorizedFailure (o lote a reconhece como
      // sistêmica) e todo ouvinte é avisado
      await expectLater(erp.get('/api/core/me'), throwsA(isA<UnauthorizedFailure>()));
      expect([second, session.lastExpired], [1, 'T']);
    });

    test('[CORRIGIDO F2B-ADV-16 LOW] 401 de NEGÓCIO (senha errada no /auth/login com sessão viva na memória) não expira a sessão',
        () async {
      final session = ProductToken()..value = 'SESSAO-VIVA'; // voltou ao login pelo "voltar" do navegador
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final api = ApiClient(
          client: MockClient((_) async => _json(401, {'error': 'Email ou senha inválidos'})),
          baseUrl: 'http://erp',
          session: session);
      await expectLater(api.post('/auth/login', {'email': 'a@b.c', 'password': 'x'}), throwsA(isA<UnauthorizedFailure>()));
      // o login não leva o Bearer da sessão (o 401 dele não é expiração)
      expect([expired, session.value], [0, 'SESSAO-VIVA']);
    });

    test('[CORRIGIDO F2B-ADV-06 MEDIUM — D-F148] 401 da nfse-api por CHAVE DESCONHECIDA (kid fora de ordem na rotação) NÃO derruba a sessão quando o emissor a aceita — vira SESSION_NOT_ACCEPTED',
        () async {
      final session = ProductToken()..value = 'T-kid2';
      var expired = 0;
      var asked = 0;
      session.addExpiredListener(() => expired++);
      session.confirmer = () async {
        asked++;
        return true; // o setes-api (GET /api/core/me) aceita o token
      };
      // o setes-api (emissor) aceita o token; a nfse-api ainda não tem a chave pública nova
      final nfse = NfseApiClient(
          client: MockClient((_) async =>
              _json(401, {'error': 'Token assinado com chave desconhecida', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://nfse',
          session: session);
      await expectLater(
          nfse.get('/v1/nfse/invoices/1'),
          throwsA(isA<Failure>()
              .having((f) => f is UnauthorizedFailure, 'não é a expiração', isFalse)
              .having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted)));
      // a sessão só morre quando o EMISSOR do token (setes-api) confirma — a
      // configuração errada de uma API não desloga o usuário em laço
      expect([expired, asked, session.value], [0, 1, 'T-kid2']);
    });

    test('[D-F148] o emissor TAMBÉM recusa (sessão morta de verdade) → expira uma vez e a requisição é UnauthorizedFailure', () async {
      final session = ProductToken()..value = 'T';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final erp = ApiClient(
          client: MockClient((_) async => _json(401, {'error': 'Token expirado', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://erp',
          session: session);
      session.confirmer = erp.sessionAlive; // como o AppWidget liga
      final nfse = NfseApiClient(
          client: MockClient((_) async => _json(401, {'error': 'Token expirado', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://nfse',
          session: session);
      await expectLater(nfse.get('/v1/nfse/invoices/1'), throwsA(isA<UnauthorizedFailure>()));
      expect([expired, session.value], [1, null]);
    });

    test('[D-F148] vários 401 JUNTOS da nfse-api perguntam ao emissor UMA vez; confirmador que FALHA não prova a morte (a sessão fica)', () async {
      final session = ProductToken()..value = 'T';
      var asked = 0;
      final gate = Completer<bool>();
      session.confirmer = () {
        asked++;
        return gate.future;
      };
      final nfse = NfseApiClient(
          client: MockClient((_) async => _json(401, {'error': 'x', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://nfse',
          session: session);
      final a = nfse.get('/v1/a').then((_) => 'ok', onError: (Object e) => (e as Failure).code);
      final b = nfse.get('/v1/b').then((_) => 'ok', onError: (Object e) => (e as Failure).code);
      await pumpEventQueue();
      gate.complete(true);
      expect(await Future.wait([a, b]), [ClientFailureCodes.sessionNotAccepted, ClientFailureCodes.sessionNotAccepted]);
      expect(asked, 1);
      session.confirmer = () => throw StateError('rede');
      await expectLater(nfse.get('/v1/c'),
          throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted)));
      expect(session.value, 'T');
    });
  });

  group('F2B-ADV-10 — NFSE_API_URL conferida pela FORMA (D-F146)', () {
    test('[CORRIGIDO F2B-ADV-10 LOW] base com barra final vira a URL certa — antes saía "//v1"', () async {
      Uri? seen;
      final nfse = NfseApiClient(
          client: MockClient((req) async {
            seen = req.url;
            return _json(200, {'ok': true, 'data': <String, dynamic>{}});
          }),
          baseUrl: 'https://api.setes.com.br/nfse/');
      await nfse.get('/v1/nfse/invoices/1');
      expect(seen.toString(), 'https://api.setes.com.br/nfse/v1/nfse/invoices/1');
    });

    test('[CORRIGIDO F2B-ADV-10 LOW] base SEM esquema = erro de CONFIGURAÇÃO (nunca NetworkFailure — "desfecho desconhecido" no app)',
        () async {
      // a URI que o ApiClient monta com NFSE_API_URL=localhost:3002
      final uri = Uri.parse('localhost:3002' '/v1/nfse/invoices/1/transmit');
      expect([uri.scheme, uri.host], ['localhost', ''], reason: 'nunca sai do navegador');
      // o que o http faz com ela (ArgumentError) — e o ApiClient chama de rede caída
      final nfse = NfseApiClient(
          client: MockClient((_) async => throw ArgumentError('Unsupported scheme localhost')),
          baseUrl: 'localhost:3002');
      // certo: erro de CONFIGURAÇÃO (o build falha alto na abertura), nunca
      // NetworkFailure — que a tela trata como "o ato pode ter acontecido"
      await expectLater(nfse.post('/v1/nfse/invoices/1/transmit', const {}),
          throwsA(isA<Failure>()
              .having((f) => f is NetworkFailure, 'rede', isFalse)
              .having((f) => f.code, 'code', ClientFailureCodes.configuration)));
    });

    test('[CORRIGIDO F2B-ADV-10 LOW] a abertura do app confere a FORMA: vazia, sem esquema/host, http fora de localhost, consulta', () {
      expect(AppConfig.urlProblems('X', ''), ['X (vazia)']);
      expect(AppConfig.urlProblems('X', 'localhost:3002'), hasLength(1));
      expect(AppConfig.urlProblems('X', 'http://nfse.setes.com.br'), hasLength(1));
      expect(AppConfig.urlProblems('X', 'https://nfse.setes.com.br/?a=1'), hasLength(1));
      for (final ok in ['http://localhost:3002', 'http://127.0.0.1:3002', 'https://nfse.setes.com.br', 'https://api.setes.com.br/nfse/']) {
        expect(AppConfig.urlProblems('X', ok), isEmpty, reason: ok);
      }
    });
  });

  test('[CORRIGIDO F2B-SOC-08/ADV-13] os dois clientes são IRMÃOS — nenhum é subtipo do outro (a injeção nunca cruza as APIs)', () {
    expect(NfseApiClient(baseUrl: 'http://nfse'), isNot(isA<ApiClient>()));
    expect(ApiClient(baseUrl: 'http://erp'), isNot(isA<NfseApiClient>()));
  });
}
