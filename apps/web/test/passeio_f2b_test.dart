// Achados do PASSEIO LOGADO da F2b (2026-10-13, 4ª sessão — §22.46.4 do prompt_apis_fiscais_isoladas.md) e as decisões do Valdo:
//   - D-F206 (= P-03 (a)): a CARGA da lista que falha sai como estado de FALHA (`loadFailed`) — a tela mostra o erro com "Tentar
//     novamente", nunca "Não encontramos nenhum registro"; o "Tentar novamente" recarrega e o estado de falha some;
//   - D-F204 (= D-F188, frase neutra): `core.errors.network` e `register.loadFailed` nas DUAS línguas, sem a frase antiga.
// O P-04 (a mensagem principal junto da do campo) é da página — coberto pela leitura do código e pelo passeio repetido.
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

import 'support/service_order_bloc_factory.dart';

void main() {
  setUpAll(() => registerFallbackValue(SearchCriteriaValues.empty));

  test('D-F206: a carga da lista que falha emite a falha E a lista em estado de falha; "Tentar novamente" recarrega e a falha some',
      () async {
    final repo = ServiceOrderRepoMock();
    var calls = 0;
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => ++calls == 1
            ? const Left(NetworkFailure(detail: 'NETWORK · setes-api'))
            : const Right(PagedResult(
                items: [ServiceOrderListItem(id: 1, number: 7373, customerId: 1, status: 'F')], page: 1, pageSize: 25, total: 1)));
    final bloc = buildServiceOrderBloc(repo: repo);
    final states = <ServiceOrderState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
    await pumpEventQueue(times: 20);
    final failed = states.whereType<ServiceOrderListState>().last;
    expect(states.whereType<ServiceOrderActionFailure>().single.failure, isA<NetworkFailure>());
    expect([failed.loadFailed, failed.loading, failed.items, failed.status], [true, false, isEmpty, 'F']);
    bloc.add(ServiceOrderListRequested(status: failed.status, filter: failed.filter, page: failed.page));   // "Tentar novamente"
    await pumpEventQueue(times: 20);
    final ok = states.whereType<ServiceOrderListState>().last;
    await sub.cancel();
    await bloc.close();
    expect([ok.loadFailed, ok.items.length], [false, 1]);
  });

  test('D-F204/D-F206: as frases novas nas duas línguas; a frase antiga da rede sumiu', () {
    Map<String, dynamic> read(String lang) =>
        jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;
    final pt = read('pt');
    final en = read('en');
    expect((pt['core'] as Map)['errors']['network'], 'Sem resposta do serviço — rede, proxy ou tempo.');
    expect((en['core'] as Map)['errors']['network'], 'No response from the service — network, proxy or timeout.');
    expect([(pt['register'] as Map)['loadFailed'], (en['register'] as Map)['loadFailed']], everyElement(isNotEmpty));
    expect(File('assets/translations/pt.json').readAsStringSync(), isNot(contains('Falha de conexão com o servidor')));
  });
}
