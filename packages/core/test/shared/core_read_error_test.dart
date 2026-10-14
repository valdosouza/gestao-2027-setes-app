// D-F210 (Valdo 2026-10-13 — gates do passeio logado da F2b, PSO-SOC-05 = PSO-ADV-03): um erro de LEITURA da resposta (200 que não é o
// que o login espera — ex.: página de um proxy) não vira "Sem resposta do serviço": é a falha de resposta ilegível do cliente
// (`CLIENT_INVALID_RESPONSE`). A queda de REDE de verdade continua chegando pelo ApiClient como NetworkFailure com o código curto.
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';

void main() {
  test('D-F210: 200 sem o token na seleção de estabelecimento = resposta ilegível (nunca rede); rede caída = NetworkFailure NETWORK · setes-api', () async {
    final odd = AuthRepositoryImpl(
        datasource: AuthRemoteDatasource(
            client: ApiClient(client: MockClient((_) async => http.Response('{"ok":true,"data":"<html>proxy</html>"}', 200)), baseUrl: 'http://erp')));
    final r = await odd.selectInstitution('sel', 1);   // a troca de estabelecimento: `json['token'] as String`
    final f = r.fold((l) => l, (_) => null)!;
    expect([f is NetworkFailure, f.code], [false, ClientFailureCodes.invalidResponse]);

    final down = AuthRepositoryImpl(
        datasource: AuthRemoteDatasource(
            client: ApiClient(client: MockClient((_) async => throw Exception('Failed to fetch')), baseUrl: 'http://erp')));
    final d = (await down.login('a@b.c', 'x')).fold((l) => l, (_) => null)!;
    expect([d is NetworkFailure, d.supportRef], [true, 'NETWORK · setes-api']);
  });
}
