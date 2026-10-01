// Lote "Transmitir pendentes" (Onda 3 — NFS-e pelo ADN) no ServiceOrderBloc:
// o que este teste fixa é (1) UM lote por vez — H1 do gate socrático da
// Rodada 5: o 2º disparo enquanto o 1º roda é IGNORADO, nada duplo no fisco —,
// (2) o fatiamento em blocos de 50 em SEQUÊNCIA com relatório agregado, (3)
// bloco que falha inteiro depois de outro já transmitido não apaga o
// relatório do que já foi ao fisco, e (4) o passo 1 (pendentes) devolve a
// lista no one-shot para a página confirmar.

import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_fiscal_repository.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_repository.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_batch_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_delete.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_cancel.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_danfse.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_pending.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_refresh.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_xml.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_getlist.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_item_delete.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_item_save.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_monthly_run.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_post.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_transmit.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

class _RepoMock extends Mock implements ServiceOrderRepository {}

class _FiscalRepoMock extends Mock implements ServiceOrderFiscalRepository {}

ServiceOrderBloc _bloc(ServiceOrderRepository repo,
        ServiceOrderFiscalRepository fiscal) =>
    ServiceOrderBloc(
      getlist: ServiceOrderGetlist(repository: repo),
      get: ServiceOrderGet(repository: repo),
      post: ServiceOrderPost(repository: repo),
      delete: ServiceOrderDelete(repository: repo),
      itemSave: ServiceOrderItemSave(repository: repo),
      itemDelete: ServiceOrderItemDelete(repository: repo),
      monthlyRun: ServiceOrderMonthlyRun(repository: repo),
      invoice: ServiceOrderInvoice(repository: repo),
      cancelInvoice: ServiceOrderCancelInvoice(repository: repo),
      batchInvoice: ServiceOrderBatchInvoice(repository: repo),
      fiscalGet: ServiceOrderFiscalGet(repository: fiscal),
      transmit: ServiceOrderTransmit(repository: fiscal),
      fiscalRefresh: ServiceOrderFiscalRefresh(repository: fiscal),
      fiscalXml: ServiceOrderFiscalXml(repository: fiscal),
      fiscalDanfse: ServiceOrderFiscalDanfse(repository: fiscal),
      fiscalCancel: ServiceOrderFiscalCancel(repository: fiscal),
      fiscalPending: ServiceOrderFiscalPendingList(repository: fiscal),
      fiscalTransmitBatch: ServiceOrderFiscalTransmitBatch(repository: fiscal),
    );

FiscalTransmitBatchReport _reportFor(List<int> ids) =>
    FiscalTransmitBatchReport.fromEntries([
      for (final id in ids) FiscalTransmitBatchRow(orderId: id, ok: true, kind: 'A'),
    ]);

List<int> _ids(int n) => List.generate(n, (i) => i + 1);

/// Dispara [event] e devolve os estados emitidos até a lista recarregar
/// (o bloc SEMPRE termina com a lista carregada, com ou sem relatório).
Future<List<ServiceOrderState>> _run(
    ServiceOrderBloc bloc, ServiceOrderEvent event) async {
  final states = <ServiceOrderState>[];
  final sub = bloc.stream.listen(states.add);
  final done = bloc.stream
      .firstWhere((s) => s is ServiceOrderListState && !s.loading);
  bloc.add(event);
  await done;
  await sub.cancel();
  await bloc.close();
  return states;
}

void main() {
  late _RepoMock repo;
  late _FiscalRepoMock fiscal;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
  });

  setUp(() {
    repo = _RepoMock();
    fiscal = _FiscalRepoMock();
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            criteria: any(named: 'criteria')))
        .thenAnswer((_) async => const Right(PagedResult.empty()));
  });

  void transmiteTudo() =>
      when(() => fiscal.transmitBatch(any())).thenAnswer((inv) async =>
          Right(_reportFor(inv.positionalArguments[0] as List<int>)));

  List<List<int>> chamadas() =>
      verify(() => fiscal.transmitBatch(captureAny()))
          .captured
          .cast<List<int>>();

  group('passo 1 — pendentes', () {
    test('devolve a lista no one-shot para a página confirmar e recarrega a lista',
        () async {
      when(fiscal.pending).thenAnswer((_) async => const Right([
            ServiceOrderFiscalPending(invoiceId: 10, number: '1'),
            ServiceOrderFiscalPending(invoiceId: 11, number: '2'),
          ]));

      final states = await _run(
          _bloc(repo, fiscal), const ServiceOrderFiscalPendingRequested());

      final loaded = states.whereType<ServiceOrderFiscalPendingLoaded>().single;
      expect(loaded.pending.map((p) => p.orderId), [10, 11]);
      verifyNever(() => fiscal.transmitBatch(any()));
    });

    test('falha do GET pendentes sobe como Failure (ponte trata)', () async {
      when(fiscal.pending).thenAnswer((_) async =>
          const Left(Failure(message: 'Sem privilégio', statusCode: 403)));

      final states = await _run(
          _bloc(repo, fiscal), const ServiceOrderFiscalPendingRequested());

      expect(states.whereType<ServiceOrderFiscalPendingLoaded>(), isEmpty);
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.statusCode,
          403);
    });
  });

  group('fatiamento do lote (teto 50 por requisição)', () {
    test('120 ordens → 3 blocos (50/50/20), em sequência, e UM relatório agregado',
        () async {
      transmiteTudo();

      final states = await _run(_bloc(repo, fiscal),
          ServiceOrderFiscalTransmitBatchRequested(_ids(120)));

      final blocos = chamadas();
      expect(blocos.map((c) => c.length), [50, 50, 20]);
      expect(blocos[1].first, 51);
      final done = states.whereType<ServiceOrderFiscalBatchDone>().single;
      expect(done.report.requested, 120);
      expect(done.report.transmitted, 120);
      expect(done.report.refused, 0);
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
    });

    test('ids repetidos contam uma vez antes de fatiar', () async {
      transmiteTudo();

      final states = await _run(_bloc(repo, fiscal),
          const ServiceOrderFiscalTransmitBatchRequested([1, 2, 2, 3, 1]));

      expect(chamadas().single, [1, 2, 3]);
      expect(states.whereType<ServiceOrderFiscalBatchDone>().single.report.requested, 3);
    });
  });

  group('um lote por vez (H1 do gate socrático da Rodada 5)', () {
    test('2º disparo enquanto o 1º ainda roda é IGNORADO — nenhuma chamada extra, um relatório só',
        () async {
      final gate = Completer<void>();
      when(() => fiscal.transmitBatch(any())).thenAnswer((inv) async {
        await gate.future; // segura o 1º lote "no fisco"
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });
      final bloc = _bloc(repo, fiscal);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final done = bloc.stream
          .firstWhere((s) => s is ServiceOrderListState && !s.loading);

      bloc.add(ServiceOrderFiscalTransmitBatchRequested(_ids(3)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ServiceOrderFiscalTransmitBatchRequested(_ids(3)));
      await Future<void>.delayed(Duration.zero);
      // nem o passo 1 entra no meio de um lote em andamento
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await done;
      await sub.cancel();
      await bloc.close();

      expect(chamadas().length, 1);
      expect(states.whereType<ServiceOrderFiscalBatchDone>().length, 1);
      verifyNever(fiscal.pending);
    });
  });

  group('bloco que falha inteiro', () {
    test('2º bloco falha → o 1º NÃO se perde: relatório agregado com as demais como recusadas',
        () async {
      var chamada = 0;
      when(() => fiscal.transmitBatch(any())).thenAnswer((inv) async {
        chamada++;
        if (chamada == 2) {
          return const Left(Failure(message: 'Fisco indisponível', statusCode: 503));
        }
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });

      final states = await _run(_bloc(repo, fiscal),
          ServiceOrderFiscalTransmitBatchRequested(_ids(120)));

      expect(chamadas().length, 2); // o 3º não é tentado
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
      final r = states.whereType<ServiceOrderFiscalBatchDone>().single.report;
      expect(r.requested, 120);
      expect(r.transmitted, 50);
      expect(r.refused, 70);
      expect(r.rows[50].orderId, 51);
      expect(r.rows[50].code, FiscalTransmitBatchRow.abortedCode);
      expect(r.rows[50].message, 'Fisco indisponível');
    });

    test('1º bloco falha → nada transmitido: sobe como Failure', () async {
      when(() => fiscal.transmitBatch(any())).thenAnswer((_) async =>
          const Left(Failure(message: 'Sem privilégio', statusCode: 403,
              code: 'PRIVILEGE_REQUIRED')));

      final states = await _run(_bloc(repo, fiscal),
          ServiceOrderFiscalTransmitBatchRequested(_ids(120)));

      expect(chamadas().length, 1);
      expect(states.whereType<ServiceOrderFiscalBatchDone>(), isEmpty);
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code,
          'PRIVILEGE_REQUIRED');
    });
  });
}
