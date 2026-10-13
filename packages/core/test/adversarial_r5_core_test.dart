// GATE ADVERSARIAL do DELTA da Rodada 5 — núcleo HTTP do app (commit 5c80e20,
// delta sobre bbeb1d6): o prazo de 15 s da pergunta ao emissor
// (`ProductToken.confirmTimeout`) em corrida com o relogin, a frase de ORIGEM
// no `supportRef` do SESSION_NOT_ACCEPTED, a LISTA das rotas públicas de
// `/auth` e o `AppConfig.urlProblems` contra o que o NAVEGADOR recusa.
//
// Convenção do gate:
//   - `[ACHADO R5-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:`. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r5_core_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre). `[FATO]` = registro.
// Nada aqui fala com servidor: MockClient do package:http.

import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

// R5-ADV-08 e R5-ADV-09 CORRIGIDOS na sessão — os testes rodam sempre.

void main() {
  group('prazo de 15 s da pergunta ao emissor × relogin (F2B-RG-06)', () {
    /// O confirmador REAL (`ApiClient.sessionAlive`) com o `/api/core/me` PENDURADO até [me] completar.
    ({ProductToken session, NfseApiClient nfse, Completer<http.Response> me, List<String> meAuth, List<int> expired}) rig() {
      final session = ProductToken()
        ..value = 'A'
        ..confirmTimeout = const Duration(milliseconds: 60);
      final expired = <int>[];
      session.addExpiredListener(() => expired.add(1));
      final me = Completer<http.Response>();
      final meAuth = <String>[];
      final erp = ApiClient(
          client: MockClient((req) async {
            meAuth.add('${req.headers['Authorization']}');
            return me.future;
          }),
          baseUrl: 'http://erp',
          session: session);
      session.confirmer = erp.sessionAlive;
      final nfse = NfseApiClient(
          client: MockClient((_) async => _json(401, {'error': 'Token assinado com chave desconhecida', 'code': 'UNAUTHORIZED'})),
          baseUrl: 'http://nfse',
          session: session);
      return (session: session, nfse: nfse, me: me, meAuth: meAuth, expired: expired);
    }

    test('[RESISTIU] relogin (B) DURANTE a pergunta pendurada: o prazo vence → "stale" (o 401 é da sessão anterior); a resposta TARDIA do /me (401 do token A) não derruba B',
        () async {
      final r = rig();
      final call = r.nfse.get('/v1/nfse/invoices/1').then<Object?>((_) => null, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      r.session.value = 'B'; // o usuário entrou de novo enquanto o /api/core/me pendia
      final failure = await call;
      expect(failure, isA<UnauthorizedFailure>(), reason: 'stale: nem "o serviço não reconheceu", nem expiração da nova');
      r.me.complete(_json(401, {'error': 'Sessão expirada', 'code': 'UNAUTHORIZED'})); // a verdade sobre A chega depois
      await pumpEventQueue();
      expect([r.meAuth, r.session.value, r.expired], [['Bearer A'], 'B', <int>[]]);
    });

    test('[FATO] sem relogin: o prazo vence → a sessão FICA (SESSION_NOT_ACCEPTED); se o /me pendurado voltar 401 depois, a sessão A expira AGORA (a própria pergunta é do emissor) — uma vez',
        () async {
      final r = rig();
      await expectLater(r.nfse.get('/v1/nfse/invoices/1'),
          throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted)));
      expect([r.session.value, r.expired], ['A', <int>[]]);
      r.me.complete(_json(401, {'error': 'Sessão expirada', 'code': 'UNAUTHORIZED'}));
      await pumpEventQueue();
      expect([r.session.value, r.expired], [null, [1]]);
    });

    test('[RESISTIU] depois do prazo, o próximo 401 pergunta de NOVO (não fica preso à pendurada); um 2º 401 no MESMO prazo junta-se à 1ª pergunta', () async {
      final r = rig();
      final a = r.nfse.get('/v1/nfse/invoices/1').catchError((Object _) => <String, dynamic>{});
      final b = r.nfse.get('/v1/nfse/invoices/2').catchError((Object _) => <String, dynamic>{});
      await Future.wait([a, b]);
      expect(r.meAuth, ['Bearer A'], reason: 'dois 401 juntos = UMA pergunta');
      await r.nfse.get('/v1/nfse/invoices/3').catchError((Object _) => <String, dynamic>{});
      expect(r.meAuth, ['Bearer A', 'Bearer A'], reason: 'depois do prazo a pergunta recomeça');
    });
  });

  group('SESSION_NOT_ACCEPTED — a frase de ORIGEM no supportRef (F2B-SOCD-07)', () {
    Future<Failure> notAccepted(Object body) async {
      final session = ProductToken()..value = 'T';
      session.confirmer = () async => true;
      final nfse = NfseApiClient(client: MockClient((_) async => _json(401, body)), baseUrl: 'http://nfse', session: session);
      try {
        await nfse.get('/v1/emitter');
      } on Failure catch (f) {
        return f;
      }
      throw StateError('não falhou');
    }

    test('[RESISTIU] código + frase de origem; só a ref; strings vazias = sem supportRef; corpo vazio = o código do cliente', () async {
      expect((await notAccepted({'code': 'UNAUTHORIZED', 'error': 'Token com kid desconhecido: k2'})).supportRef,
          'UNAUTHORIZED: Token com kid desconhecido: k2');
      expect((await notAccepted({'ref': 'AB12'})).supportRef, 'AB12');
      expect((await notAccepted({'code': '', 'error': ''})).supportRef, isNull);
      expect((await notAccepted(<String, dynamic>{})).code, ClientFailureCodes.sessionNotAccepted);
    });

    test('[CORRIGIDO R5-ADV-09 LOW — fora do delta, ADJACENTE] 401 com `error` que não é string (o JSON de erro de um gateway/WAF: `{"error": {"code": 401, …}}`): o `body[\'error\'] as String?` da LINHA ANTERIOR à frase de origem (api_client.dart:187 — e o mesmo cast no ramo ≥ 400) lança TypeError — a defesa nova (`whereType<String>`) nunca roda, nada expira/confirma e o TypeError escapa do `on Failure` das telas (a classe do F2B-ADV-12)',
        () async {
      final f = await notAccepted({'code': 'UNAUTHORIZED', 'error': {'code': 401, 'message': 'gateway'}, 'ref': 'R1'})
          .then<Object>((f) => f, onError: (Object e) => e);
      expect(f, isA<Failure>());
      final erp = ApiClient(client: MockClient((_) async => _json(403, {'error': 123})), baseUrl: 'http://erp', session: ProductToken());
      await expectLater(erp.get('/api/x'), throwsA(isA<Failure>()));
    });
  });

  group('rotas públicas de /auth — LISTA (F2B-RG-04)', () {
    test('[RESISTIU] login/seleção/recuperação/troca de senha vão SEM o Bearer da sessão; a switch-institution (exige a sessão) vai COM; um 401 da switch-institution com a sessão expira (é o emissor)',
        () async {
      final session = ProductToken()..value = 'S';
      var expired = 0;
      session.addExpiredListener(() => expired++);
      final seen = <String, String?>{};
      final erp = ApiClient(
          client: MockClient((req) async {
            seen[req.url.path] = req.headers['Authorization'];
            return _json(401, {'error': 'x', 'code': 'UNAUTHORIZED'});
          }),
          baseUrl: 'http://erp',
          session: session);
      for (final p in ['/auth/login', '/auth/select-institution', '/auth/recovery-password', '/auth/change-password']) {
        await expectLater(erp.post(p, const {}), throwsA(isA<UnauthorizedFailure>()));
      }
      expect([session.value, expired], ['S', 0]);
      await expectLater(erp.post('/auth/switch-institution', const {}), throwsA(isA<UnauthorizedFailure>()));
      expect(seen, {
        '/auth/login': null, '/auth/select-institution': null, '/auth/recovery-password': null, '/auth/change-password': null,
        '/auth/switch-institution': 'Bearer S',
      });
      expect([session.value, expired], [null, 1]);
    });
  });

  group('AppConfig.urlProblems × o que o NAVEGADOR recusa (F2B-RG-08)', () {
    test('[CORRIGIDO R5-ADV-08 LOW] host que termina em NÚMERO e não é IPv4 válido (WHATWG: o navegador o parseia como IPv4 e RECUSA a URL) passa na conferência da abertura — cada ato vira NetworkFailure = "desfecho desconhecido", a classe que o RG-08 diz ter fechado',
        () {
      for (final v in ['https://a.1', 'https://nfse.setes.com.1', 'https://999.999.999.999', 'https://1.2.3.4.5', 'https://256.0.0.1']) {
        expect([v, AppConfig.urlProblems('NFSE_API_URL', v)], [v, isNotEmpty]);
      }
    });

    test('[RESISTIU] IPv6 com colchetes, porta padrão, maiúsculas (o Dart normaliza o host) e IPv4 válido passam; credencial, porta 0/65536 e espaço recusam', () {
      for (final ok in ['https://[2001:db8::1]', 'https://api.setes.com.br:443', 'https://API.Setes.com.BR', 'https://203.0.113.5', 'http://localhost:3002']) {
        expect([ok, AppConfig.urlProblems('NFSE_API_URL', ok)], [ok, isEmpty]);
      }
      for (final bad in ['https://u:p@api.setes.com.br', 'https://api.setes.com.br:0', 'https://api.setes.com.br:65536', 'https://api setes.com.br']) {
        expect([bad, AppConfig.urlProblems('NFSE_API_URL', bad)], [bad, isNotEmpty]);
      }
    });
  });
}
