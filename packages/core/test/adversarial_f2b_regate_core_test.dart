// RE-GATE ADVERSARIAL da F2b — núcleo HTTP do app (commit bbeb1d6, delta sobre
// 289de28): o confirmador da D-F148 (`ProductToken.confirm` +
// `ApiClient.sessionAlive`), a isenção das rotas `/auth/*`, o envelope estrito
// contra as rotas REAIS da nfse-api e a conferência da URL (`AppConfig`).
//
// Convenção do gate (a mesma do gate anterior):
//   - `[ACHADO F2B-RG-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_f2b_regate_core_test.dart
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

// CORRIGIDOS na sessão (rodam sempre): RG-04 (lista explícita das rotas públicas de /auth), RG-06 (prazo da confirmação — 15 s,
// "não prova a morte"), RG-08 (porta, credenciais e host na conferência da URL).

/// O 401 que a nfse-api devolve no `productAuth` (fiscal-api/src/auth/product-jwt.ts:105-112): `{ error, code }`, sem `ref`.
http.Response _nfse401([String error = 'Token assinado com chave desconhecida']) =>
    _json(401, {'error': error, 'code': 'UNAUTHORIZED'});

void main() {
  // ---------------------------------------------------------------------
  // 1. O confirmador da D-F148
  // ---------------------------------------------------------------------
  group('D-F148 — o EMISSOR confirma o 401 da nfse-api', () {
    test('[RESISTIU] laço: o confirmador REAL (sessionAlive) faz UM GET /api/core/me no setes-api, com o MESMO Bearer, e nunca volta à nfse-api',
        () async {
      final session = ProductToken()..value = 'T';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final erpCalls = <String>[];
      final nfseCalls = <String>[];
      final erp = ApiClient(
          client: MockClient((req) async {
            erpCalls.add('${req.method} ${req.url.path} ${req.headers['Authorization']}');
            return _json(200, {'ok': true, 'data': {'userId': 1}});
          }),
          baseUrl: 'http://erp',
          session: session);
      session.confirmer = erp.sessionAlive; // como o AppWidget liga
      final nfse = NfseApiClient(
          client: MockClient((req) async {
            nfseCalls.add('${req.method} ${req.url.path}');
            return _nfse401();
          }),
          baseUrl: 'http://nfse',
          session: session);
      await expectLater(nfse.get('/v1/nfse/invoices/1'),
          throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted)));
      expect(nfseCalls, ['GET /v1/nfse/invoices/1']);
      expect(erpCalls, ['GET /api/core/me Bearer T']);
      expect([expired, session.value], [0, 'T']);
    });

    test('[RESISTIU] o emissor responde 200 mas o token JÁ foi trocado (troca de institution no meio): a sessão NOVA fica intacta e nada expira',
        () async {
      final session = ProductToken()..value = 'T1';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final me = Completer<bool>();
      session.confirmer = () => me.future;
      final nfse = NfseApiClient(client: MockClient((_) async => _nfse401()), baseUrl: 'http://nfse', session: session);
      final call = nfse.get('/v1/nfse/invoices/1').then<Object?>((_) => null, onError: (Object e) => e);
      await pumpEventQueue();
      session.value = 'T2'; // switch-institution / relogin durante a confirmação
      me.complete(true); // o /api/core/me (com T1) aceitou
      final failure = await call;
      // stale: o 401 é da sessão ANTERIOR — não é "o serviço não reconheceu" nem expiração da nova
      expect(failure, isA<UnauthorizedFailure>());
      expect([expired, session.value], [0, 'T2']);
    });

    test('[RESISTIU] relogin durante a confirmação e o emissor RECUSA o token velho: o 401 do /api/core/me (T1) não derruba a sessão nova (T2)',
        () async {
      final session = ProductToken()..value = 'T1';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final gate = Completer<void>();
      final erp = ApiClient(
          client: MockClient((req) async {
            await gate.future;
            return _json(401, {'error': 'Token expirado', 'code': 'UNAUTHORIZED'});
          }),
          baseUrl: 'http://erp',
          session: session);
      session.confirmer = erp.sessionAlive;
      final nfse = NfseApiClient(client: MockClient((_) async => _nfse401('Token expirado')), baseUrl: 'http://nfse', session: session);
      final call = nfse.get('/v1/nfse/invoices/1').then<Object?>((_) => null, onError: (Object e) => e);
      await pumpEventQueue();
      session.value = 'T2';
      gate.complete();
      expect(await call, isA<UnauthorizedFailure>());
      expect([expired, session.value], [0, 'T2']);
    });

    test('[RESISTIU] 401 de tokens DIFERENTES ao mesmo tempo: o do token velho é stale sem perguntar; o do atual pergunta UMA vez',
        () async {
      final session = ProductToken()..value = 'T2';
      var asked = 0;
      session.confirmer = () async {
        asked++;
        return true;
      };
      expect(await session.confirm('T1'), SessionCheck.stale);
      final checks = await Future.wait([session.confirm('T2'), session.confirm('T2'), session.confirm('T1')]);
      expect(checks, [SessionCheck.alive, SessionCheck.alive, SessionCheck.stale]);
      expect(asked, 1);
      expect(session.value, 'T2');
    });

    testWidgets(
        '[CORRIGIDO F2B-RG-06 LOW] confirmação SEM prazo: /api/core/me pendurado pendura a chamada da nfse-api — e, pela deduplicação, toda 401 SEGUINTE do mesmo token, mesmo com o setes-api de volta',
        (tester) async {
      final session = ProductToken()..value = 'T';
      session.confirmer = () => Completer<bool>().future; // o setes-api aceitou a conexão e não responde (pool esgotado)
      final nfse = NfseApiClient(client: MockClient((_) async => _nfse401()), baseUrl: 'http://nfse', session: session);
      Object? first;
      unawaited(nfse.get('/v1/nfse/invoices/1').then((_) => first = 'ok', onError: (Object e) => first = e));
      await tester.pump(const Duration(minutes: 5));
      // certo: depois de um prazo, a confirmação que não volta "não prova a morte" (D-F148) — a sessão fica e a tela diz
      expect(first, isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted),
          reason: 'a OS faturada aberta ficaria com a seção "No fisco" carregando sem fim');
      // o setes-api voltou: uma 401 nova não pode ficar presa na confirmação pendurada
      session.confirmer = () async => true;
      Object? second;
      unawaited(nfse.get('/v1/nfse/invoices/2').then((_) => second = 'ok', onError: (Object e) => second = e));
      await tester.pump(const Duration(seconds: 1));
      expect(second, isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted));
      expect(session.value, 'T');
    });

    test('[RESISTIU] SESSION_NOT_ACCEPTED não é UnauthorizedFailure (a ponte não manda ao login) e carrega o status 401 + o motivo da nfse-api no suporte',
        () async {
      final session = ProductToken()..value = 'T'
        ..confirmer = () async => true;
      final nfse = NfseApiClient(
          client: MockClient((_) async => _json(401, {'error': 'Token não corresponde a uma institution ativa com este schema', 'code': 'INSTITUTION_MISMATCH'})),
          baseUrl: 'http://nfse',
          session: session);
      await expectLater(
          nfse.post('/v1/nfse/invoices/1/transmit', const {}),
          throwsA(isA<Failure>()
              .having((f) => f is UnauthorizedFailure, 'unauthorized', isFalse)
              .having((f) => f.statusCode, 'status', 401)
              .having((f) => f.supportRef, 'ref', contains('institution'))));
    });
  });

  // ---------------------------------------------------------------------
  // 2. Rotas `/auth/*` sem o Bearer da sessão (F2B-ADV-16)
  // ---------------------------------------------------------------------
  group('rotas /auth/* do setes-api', () {
    Future<String?> bearerOf(String path, {String? overrideToken}) async {
      String? auth;
      final api = ApiClient(
          client: MockClient((req) async {
            auth = req.headers['Authorization'];
            return _json(200, {'ok': true, 'token': 'NOVO'});
          }),
          baseUrl: 'http://erp',
          session: ProductToken()..value = 'SESSAO');
      await api.post(path, const {}, overrideToken: overrideToken);
      return auth;
    }

    test('[RESISTIU] login, recuperação e troca de senha (sem authMiddleware no setes-api) seguem SEM o Bearer da sessão; a seleção leva o token de seleção',
        () async {
      expect(await bearerOf('/auth/login'), isNull);
      expect(await bearerOf('/auth/recovery-password'), isNull);
      expect(await bearerOf('/auth/change-password'), isNull);
      expect(await bearerOf('/auth/select-institution', overrideToken: 'SELECAO'), 'Bearer SELECAO');
      expect(await bearerOf('/api/core/me'), 'Bearer SESSAO');
    });

    test('[CORRIGIDO F2B-RG-04 LOW] /auth/switch-institution exige a sessão no setes-api (authMiddleware — setes-api auth.routes.ts:303) e precisa levar o Bearer',
        () async {
      // hoje a isenção é por PREFIXO (api_client.dart:146): o switch sai sem token → 401 "Token ausente",
      // e como a requisição "não levou a sessão" o 401 nem expira nada — a troca de institution
      // simplesmente nunca funciona por este cliente
      expect(await bearerOf('/auth/switch-institution'), 'Bearer SESSAO');
    });
  });

  // ---------------------------------------------------------------------
  // 3. Envelope estrito × as rotas REAIS da nfse-api
  // ---------------------------------------------------------------------
  group('envelope estrito da nfse-api × as rotas reais', () {
    Future<Map<String, dynamic>> through(Object body, {int status = 200}) =>
        NfseApiClient(client: MockClient((_) async => _json(status, body)), baseUrl: 'http://nfse').get('/v1/x');

    test('[RESISTIU] toda resposta 2xx da nfse-api passa: sendOk (fiscal-api http.ts:15 — emitter GET/PUT/DELETE, transmit 201, xml, danfse) e as pendentes (nfse.routes.ts:41)',
        () async {
      // /v1/emitter (GET, PUT /issuers/:model, DELETE /issuers/:model) → EmitterView
      expect((await through({'ok': true, 'data': {'issuers': [], 'certificate': {'certificate': false, 'privateKey': false}}}))['ok'], isTrue);
      // PUT/DELETE /v1/emitter/certificate → IssuerCertificateStatus
      expect((await through({'ok': true, 'data': {'certificate': true, 'privateKey': true}}))['ok'], isTrue);
      // POST transmit → 201
      expect((await through({'ok': true, 'data': {'invoiceId': 1, 'attempt': 1}}, status: 201))['ok'], isTrue);
      // GET danfse / xml
      expect((await through({'ok': true, 'data': {'accessKey': 'K', 'pdfBase64': 'JVBERi0='}}))['ok'], isTrue);
      // GET pending — `{ ok: true, ...{ data, page, pageSize, total } }` (sem `sendOk`)
      final page = await through({'ok': true, 'data': [], 'page': 1, 'pageSize': 100, 'total': 0});
      expect(envelopePage(page)['total'], 0);
    });

    test('[RESISTIU] 204 sem corpo (a nfse-api só devolve 204 no preflight OPTIONS — fiscal-api http.ts:133) é falha técnica, nunca sucesso vazio',
        () async {
      final nfse = NfseApiClient(client: MockClient((_) async => http.Response('', 204)), baseUrl: 'http://nfse');
      await expectLater(nfse.delete('/v1/emitter/issuers/SE'),
          throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.invalidResponse)));
    });
  });

  // ---------------------------------------------------------------------
  // 4. AppConfig.urlProblems (F2B-ADV-10)
  // ---------------------------------------------------------------------
  group('AppConfig.urlProblems', () {
    test('[RESISTIU] IP de LAN em http e esquema torto continuam recusados (API_URL também — o navegador da produção é https)', () {
      for (final bad in ['http://192.168.0.10:3000', 'http://10.0.2.2:3000', 'ftp://nfse.setes.com.br', 'https:/nfse.setes.com.br', '//nfse.setes.com.br']) {
        expect(AppConfig.urlProblems('API_URL', bad), isNotEmpty, reason: bad);
      }
      expect(AppConfig.urlProblems('API_URL', 'https://[2001:db8::1]:8443'), isEmpty, reason: 'IPv6 em https é URL válida');
    });

    test('[CORRIGIDO F2B-RG-08 LOW] URL que o NAVEGADOR recusa (porta fora da faixa, credenciais na URL, host com espaço) tem de ser erro de CONFIGURAÇÃO na abertura — senão cada ato vira NetworkFailure = "desfecho desconhecido"',
        () {
      // Dart aceita as três (Uri.tryParse): porta 99999; userInfo `u:p`; host `nfse%20setes.com.br`.
      // O `fetch` do navegador lança TypeError para as três → ClientException → NetworkFailure
      // (api_client.dart:160) — a mesma classe do F2B-ADV-10.
      for (final bad in ['https://nfse.setes.com.br:99999', 'https://u:p@nfse.setes.com.br', 'https://nfse setes.com.br']) {
        expect(AppConfig.urlProblems('NFSE_API_URL', bad), isNotEmpty, reason: bad);
      }
    });
  });
}
