// D27 (Q-P6, Valdo 2026-09-19): a API aceita 50 ordens por requisição; a tela
// NÃO recusa seleção maior — o bloc fatia em blocos, chama em SEQUÊNCIA e
// agrega os relatórios. O que este teste fixa é o contrato do fatiamento: o
// tamanho dos blocos, a ordem, a agregação e o que acontece quando um bloco
// falha inteiro depois de outro já ter faturado (o relatório é a prova do que
// foi cobrado — não pode se perder).

import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_repository.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_batch_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_delete.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_getlist.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_item_delete.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_item_save.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_monthly_run.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_post.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

class _RepoMock extends Mock implements ServiceOrderRepository {}

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);

ServiceOrderBloc _bloc(ServiceOrderRepository repo) => ServiceOrderBloc(
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
    );

BatchInvoiceReport _reportFor(List<int> ids) => BatchInvoiceReport.fromEntries([
      for (final id in ids)
        BatchInvoiceEntry(
            orderId: id, ok: true, invoiceNumber: '$id',
            chargedParcels: 1, chargeableParcels: 1),
    ]);

List<int> _ids(int n) => List.generate(n, (i) => i + 1);

/// Dispara o lote e devolve os estados emitidos até a lista recarregar
/// (o bloc SEMPRE termina com a lista carregada, com ou sem relatório).
Future<List<ServiceOrderState>> _run(
    ServiceOrderBloc bloc, List<int> orderIds) async {
  final states = <ServiceOrderState>[];
  final sub = bloc.stream.listen(states.add);
  final done = bloc.stream.firstWhere(
      (s) => s is ServiceOrderListState && !s.loading);
  bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: orderIds, input: _input));
  await done;
  await sub.cancel();
  await bloc.close();
  return states;
}

void main() {
  late _RepoMock repo;

  setUpAll(() {
    registerFallbackValue(_input);
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    repo = _RepoMock();
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .thenAnswer((_) async => const Right(PagedResult.empty()));
  });

  void faturaTudo() =>
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async =>
          Right(_reportFor(inv.positionalArguments[0] as List<int>)));

  List<List<int>> chamadas() =>
      verify(() => repo.batchInvoice(captureAny(), any()))
          .captured
          .cast<List<int>>();

  group('fatiamento do lote (D27)', () {
    test('120 ordens → 3 blocos (50/50/20), em sequência, e UM relatório agregado',
        () async {
      faturaTudo();

      final states = await _run(_bloc(repo), _ids(120));

      final blocos = chamadas();
      expect(blocos.map((c) => c.length), [50, 50, 20]);
      expect(blocos[0].first, 1);
      expect(blocos[1].first, 51);
      expect(blocos[2].last, 120);

      final done = states.whereType<ServiceOrderBatchInvoiceDone>().single;
      expect(done.report.requested, 120);
      expect(done.report.invoiced, 120);
      expect(done.report.failed, 0);
      expect(done.report.results.map((e) => e.orderId).toList(), _ids(120));
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
    });

    test('até 50 ordens → UMA chamada, sem fatiar (comportamento anterior preservado)',
        () async {
      faturaTudo();

      final states = await _run(_bloc(repo), _ids(50));

      expect(chamadas().single.length, 50);
      expect(states.whereType<ServiceOrderBatchInvoiceDone>().single.report.requested, 50);
    });

    test('ids repetidos contam uma vez antes de fatiar (o 2º viraria recusa que o operador não cometeu)',
        () async {
      faturaTudo();

      final states = await _run(_bloc(repo), [1, 2, 2, 3, 1]);

      expect(chamadas().single, [1, 2, 3]);
      expect(states.whereType<ServiceOrderBatchInvoiceDone>().single.report.requested, 3);
    });
  });

  group('um lote por vez (H1 do gate socrático da Rodada 5)', () {
    test('2º disparo enquanto o 1º ainda roda é IGNORADO — nenhuma chamada extra, um relatório só',
        () async {
      final gate = Completer<void>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        await gate.future; // segura o 1º lote "em contenção"
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final done = bloc.stream
          .firstWhere((s) => s is ServiceOrderListState && !s.loading);

      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(3), input: _input));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(3), input: _input));
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await done;
      await sub.cancel();
      await bloc.close();

      expect(chamadas().length, 1);
      expect(states.whereType<ServiceOrderBatchInvoiceDone>().length, 1);
    });
  });

  group('bloco que falha inteiro (D27)', () {
    test('2º bloco falha → o 1º NÃO se perde: relatório agregado, ordens do 2º e do 3º como "tente de novo"',
        () async {
      var chamada = 0;
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        chamada++;
        if (chamada == 2) {
          return const Left(Failure(message: 'Falha de rede', statusCode: 503));
        }
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });

      final states = await _run(_bloc(repo), _ids(120));

      // o 3º bloco NÃO é tentado — quem falhou no 2º falharia de novo; o
      // operador decide depois de ver o relatório
      expect(chamadas().length, 2);
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
      final r = states.whereType<ServiceOrderBatchInvoiceDone>().single.report;
      expect(r.requested, 120);
      expect(r.invoiced, 50);          // 1º bloco
      expect(r.failed, 70);            // 2º + 3º blocos
      expect(r.retryable, 70);
      expect(r.results[50].orderId, 51);
      expect(r.results[50].code, BatchInvoiceEntry.abortedCode);
      expect(r.results[50].error, 'Falha de rede');
      expect(r.results[50].retryable, isTrue);
      expect(r.results.last.orderId, 120);
    });

    test('1º bloco falha → nada faturado: sobe como Failure (a ponte trata 403/400 como sempre)',
        () async {
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async =>
          const Left(Failure(message: 'Sem privilégio', statusCode: 403,
              code: 'PRIVILEGE_REQUIRED')));

      final states = await _run(_bloc(repo), _ids(120));

      expect(chamadas().length, 1);
      expect(states.whereType<ServiceOrderBatchInvoiceDone>(), isEmpty);
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code,
          'PRIVILEGE_REQUIRED');
    });
  });
}
