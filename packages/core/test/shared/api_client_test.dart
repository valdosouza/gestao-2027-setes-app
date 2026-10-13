import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// D-F138 (F2b): o token do produto é UM ([ProductToken]) para as N APIs, e
/// o 401 numa requisição que levou o token da sessão expira a sessão para
/// todas — uma vez, e só se o token ainda é o mesmo.
void main() {
  http.Response json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('ProductToken compartilhado', () {
    test('os clientes de duas APIs leem o MESMO token a cada requisição (trocar vale para os dois)', () async {
      final seen = <String, String?>{};
      MockClient recorder(String api) => MockClient((req) async {
            seen[api] = req.headers['Authorization'];
            return json(200, {'ok': true});
          });
      final session = ProductToken();
      final erp = ApiClient(client: recorder('erp'), baseUrl: 'http://erp', session: session);
      final nfse = NfseApiClient(client: recorder('nfse'), baseUrl: 'http://nfse', session: session);
      erp.token = 'T1';
      await erp.get('/x');
      await nfse.get('/y');
      expect(seen, {'erp': 'Bearer T1', 'nfse': 'Bearer T1'});
      nfse.token = 'T2'; // troca de institution numa porta qualquer
      await erp.get('/x');
      expect(seen['erp'], 'Bearer T2');
      erp.token = null; // logout
      await nfse.get('/y');
      expect(seen['nfse'], isNull);
    });
  });

  group('401 global (D-F138)', () {
    test('401 numa requisição que LEVOU o token da sessão → expira UMA vez, para todas as APIs, e ainda lança UnauthorizedFailure', () async {
      final session = ProductToken()..value = 'T1';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final nfse = NfseApiClient(
          client: MockClient((_) async => json(401, {'error': 'Token inválido', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://nfse', session: session);
      await expectLater(nfse.get('/v1/nfse/invoices/1'), throwsA(isA<UnauthorizedFailure>()));
      expect([expired, session.value], [1, null]);
      // 2º 401 (sem token agora) não repete a expiração
      await expectLater(nfse.get('/v1/nfse/invoices/1'), throwsA(isA<UnauthorizedFailure>()));
      expect(expired, 1);
    });
    test('401 SEM token (login) e 401 do token de SELEÇÃO (overrideToken) NÃO expiram a sessão', () async {
      final session = ProductToken();
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final api = ApiClient(client: MockClient((_) async => json(401, {'error': 'Credenciais inválidas'})),
          baseUrl: 'http://erp', session: session);
      await expectLater(api.post('/auth/login', {}), throwsA(isA<UnauthorizedFailure>()));
      session.value = 'SESSAO';
      await expectLater(api.post('/auth/select', {}, overrideToken: 'SELECAO'), throwsA(isA<UnauthorizedFailure>()));
      expect([expired, session.value], [0, 'SESSAO']);
    });
    test('401 ATRASADO de uma sessão anterior não derruba o login novo (o token mudou no meio)', () async {
      final session = ProductToken()..value = 'VELHO';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final api = ApiClient(
          client: MockClient((_) async {
            session.value = 'NOVO'; // login novo enquanto a requisição velha estava no ar
            return json(401, {'error': 'Token expirado'});
          }),
          baseUrl: 'http://erp', session: session);
      await expectLater(api.get('/api/x'), throwsA(isA<UnauthorizedFailure>()));
      expect([expired, session.value], [0, 'NOVO']);
    });
    test('o ouvinte removido não é mais avisado', () {
      final session = ProductToken()..value = 'T';
      var calls = 0;
      final remove = session.addExpiredListener(() => calls++);
      remove();
      session.expire('T');
      expect([calls, session.value], [0, null]);
    });
  });

  group('envelope', () {
    test('erro com code/ref/fields vira Failure tipada (503 da voz do fisco — D-F130)', () async {
      final api = ApiClient(
          client: MockClient((_) async => json(503, {'error': 'Situação indisponível', 'code': 'FISCAL_VOICE_UNAVAILABLE', 'ref': 'REF1'})),
          baseUrl: 'http://erp');
      await expectLater(api.get('/api/billing/1/fiscal-effect'),
          throwsA(isA<Failure>().having((f) => [f.statusCode, f.code, f.supportRef], 'tipo', [503, 'FISCAL_VOICE_UNAVAILABLE', 'REF1'])));
    });
    test('corpo que não é JSON (página de proxy) vira Failure com o status — nunca FormatException', () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html>502 Bad Gateway</html>', 502)), baseUrl: 'http://erp');
      await expectLater(api.get('/x'), throwsA(isA<Failure>().having((f) => f.statusCode, 'status', 502)));
    });
    test('queda de rede vira NetworkFailure com o detalhe', () async {
      final api = ApiClient(client: MockClient((_) async => throw Exception('Failed to fetch')), baseUrl: 'http://erp');
      await expectLater(api.get('/x'), throwsA(isA<NetworkFailure>()));
    });
  });

  test('AppConfig.missingConfiguration aponta NFSE_API_URL quando o build não a define (D-F146)', () {
    // nos testes não há --dart-define: a URL da nfse-api falta (o main falha alto)
    expect(AppConfig.missingConfiguration(), contains('NFSE_API_URL'));
  });
}
