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
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_repository.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

import 'support/service_order_bloc_factory.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);

ServiceOrderBloc _bloc(ServiceOrderRepository repo) => buildServiceOrderBloc(repo: repo);

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
  late ServiceOrderRepoMock repo;

  setUpAll(() {
    registerFallbackValue(_input);
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
  });

  setUp(() {
    repo = ServiceOrderRepoMock();
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            criteria: any(named: 'criteria')))
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

  group('D-F156 (= Q-F164 (a) — decide a Q-R5.2): a tela SAI no meio do lote', () {
    test('o bloco em voo termina; os blocos seguintes NÃO são enviados e não há relatório (o já faturado fica na aba Faturadas)', () async {
      final gate = Completer<void>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        await gate.future; // o 1º bloco está "no servidor"
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(120), input: _input));
      await Future<void>.delayed(Duration.zero);
      bloc.stopBatches(); // o onDispose do módulo (D-F160)
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      await bloc.close();

      expect(chamadas().map((c) => c.length), [50], reason: 'só o bloco que já estava em voo');
      expect(states.whereType<ServiceOrderBatchInvoiceDone>(), isEmpty, reason: 'tela fechada = sem relatório');
    });

    test('a parada com o bloc OCIOSO não vaza para o próximo lote (zera no início)', () async {
      faturaTudo();
      final bloc = _bloc(repo);
      bloc.stopBatches();
      final states = await _run(bloc, _ids(60));
      expect(chamadas().map((c) => c.length), [50, 10]);
      expect(states.whereType<ServiceOrderBatchInvoiceDone>().single.report.requested, 60);
    });
  });

  group('R7-SOC-03 (gate socrático da Rodada 7): a recarga SUPERADA não emite', () {
    test('a lista pedida no MEIO do lote (página recriada) que responde DEPOIS da recarga final nunca sobrescreve a foto nova', () async {
      final gate = Completer<void>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        await gate.future;
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });
      final slow = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      var listCalls = 0;
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        listCalls++;
        if (listCalls == 1) return slow.future;                             // a página recriada no meio do lote
        return Future.value(const Right(PagedResult(items: [], page: 1, pageSize: 25, total: 99)));   // a recarga FINAL do lote
      });
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(3), input: _input));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      slow.complete(const Right(PagedResult(items: [], page: 1, pageSize: 25, total: 1)));    // a foto VELHA chega por último
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      final lists = states.whereType<ServiceOrderListState>().where((s) => !s.loading).toList();
      expect(lists.map((s) => s.total), [99], reason: 'só a recarga final emite a lista; a superada é descartada');
    });
  });

  group('D-F174 (= Q-F182 (b)): entrar no detalhe invalida a recarga da lista em voo', () {
    test('a lista lenta que responde DEPOIS de o detalhe abrir não emite — o operador fica na OS', () async {
      final slow = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      var listCalls = 0;
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        listCalls++;
        return listCalls == 1 ? slow.future : Future.value(const Right(PagedResult.empty()));
      });
      when(() => repo.getById(any())).thenAnswer((_) async => const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'A')));
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                    // fica no ar
      await Future<void>.delayed(Duration.zero);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(7));
      await detail;
      slow.complete(const Right(PagedResult(items: [], page: 1, pageSize: 25, total: 5)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      final shown = states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).toList();
      expect(shown.last, isA<ServiceOrderDetailState>());
    });
  });

  group('R9-SOC-01/02/04 (gate socrático da Rodada 9): UM contador da tela — vale o último pedido', () {
    void detailOf(int id) =>
        when(() => repo.getById(any())).thenAnswer((_) async => Right(ServiceOrderFull(id: id, customerId: 1, status: 'A')));
    List<ServiceOrderState> shownOf(List<ServiceOrderState> s) =>
        s.where((x) => x is ServiceOrderListState || x is ServiceOrderDetailState).toList();

    test('R9-SOC-04 (ii): o detalhe em voo NÃO vence uma lista pedida DEPOIS dele (troca de aba)', () async {
      final slow = Completer<Either<Failure, ServiceOrderFull>>();
      when(() => repo.getById(any())).thenAnswer((_) => slow.future);
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderViewRequested(7));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));                    // o operador trocou de aba
      await Future<void>.delayed(const Duration(milliseconds: 5));
      slow.complete(const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'A')));        // o detalhe chega DEPOIS
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      expect(shownOf(states).last, isA<ServiceOrderListState>());
      expect(states.whereType<ServiceOrderDetailState>(), isEmpty);
    });

    test('R9-SOC-02: o lote começa com um detalhe "aberto" atrás do diálogo → a tela vira a lista e o FIM recarrega (nunca fica no spinner)', () async {
      detailOf(7);
      faturaTudo();
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(7));
      await detail;
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(3), input: _input));
      await done;
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderBatchInvoiceDone>(), hasLength(1));
      final last = shownOf(states).last as ServiceOrderListState;
      expect(last.loading, isFalse);
    });

    test('R9-SOC-01: o 1º bloco do lote FALHA (504) com uma OS aberta no meio → a falha aparece e o operador FICA na OS', () async {
      final gate = Completer<void>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async {
        await gate.future;
        return const Left(Failure(message: 'gw', statusCode: 504));
      });
      detailOf(9);
      when(() => repo.open(any())).thenAnswer((_) async => const Right(9));
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(60), input: _input));
      await Future<void>.delayed(Duration.zero);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderOpenRequested(5));                                              // o FAB no meio do lote
      await detail;
      final failed = bloc.stream.firstWhere((s) => s is ServiceOrderActionFailure);
      gate.complete();
      await failed;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      expect(shownOf(states).last, isA<ServiceOrderDetailState>());
    });
  });

  group('D-F177/D-F178 (= Q-F185 (a)/Q-F186 (a)): as saídas longas respeitam a OS aberta; o detalhe preservado não é relido', () {
    test('D-F177: a rotina mensal termina com uma OS aberta no meio → o relatório sai e o operador FICA na OS (nenhuma recarga)', () async {
      final gate = Completer<void>();
      when(() => repo.monthlyRun(any(), any())).thenAnswer((_) async {
        await gate.future;
        return const Right(MonthlyRunReport(processed: 3));
      });
      when(() => repo.getById(any())).thenAnswer((_) async => const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'A')));
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await Future<void>.delayed(Duration.zero);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(7));
      await detail;
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderMonthlyRunDone);
      gate.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      final shown = states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).toList();
      expect(shown.last, isA<ServiceOrderDetailState>());
    });

    test('D-F178 (conhecimento negativo): o fim do lote com a OS aberta NÃO relê o detalhe — ele fica como foi carregado', () async {
      final gate = Completer<void>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        await gate.future;
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });
      when(() => repo.getById(any())).thenAnswer((_) async => const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'A')));
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(3), input: _input));
      await Future<void>.delayed(Duration.zero);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(7));
      await detail;
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderBatchInvoiceDone);
      gate.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      verify(() => repo.getById(7)).called(1);                                                   // uma carga só — sem releitura
      final last = states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).last as ServiceOrderDetailState;
      expect(last.order.status, 'A');
    });
  });

  group('R10-SOC-01/03 (gate socrático do delta da Rodada 10): "a caminho" até o detalhe NASCER; o ato confere a tela que capturou', () {
    List<ServiceOrderState> shownOf(List<ServiceOrderState> s) =>
        s.where((x) => x is ServiceOrderListState || x is ServiceOrderDetailState).toList();

    Future<void> slowVoiceDetail(NfseRepoMock nfse, InvoiceRepoMock invoice, Completer<void> voice) async {
      when(() => repo.getById(any())).thenAnswer((_) async => const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'F')));
      when(() => nfse.getView(any())).thenAnswer((_) async {
        await voice.future;
        return const Right(ServiceOrderFiscalView());
      });
      when(() => invoice.fiscalEffect(any())).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
    }

    test('R10-SOC-01: a rotina mensal termina ENTRE o GET da OS faturada e a voz do fisco → o operador FICA na OS (a marca só morre quando o detalhe nasce)', () async {
      final gate = Completer<void>();
      final voice = Completer<void>();
      final nfse = NfseRepoMock();
      final invoice = InvoiceRepoMock();
      when(() => repo.monthlyRun(any(), any())).thenAnswer((_) async {
        await gate.future;
        return const Right(MonthlyRunReport(processed: 3));
      });
      await slowVoiceDetail(nfse, invoice, voice);
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ServiceOrderViewRequested(7));                                             // a OS faturada: a voz do fisco demora
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderMonthlyRunDone);
      gate.complete();                                                                           // a rotina termina AQUI
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      voice.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      expect(shownOf(states).last, isA<ServiceOrderDetailState>());
      verifyNever(() => repo.getList(any(), any(),
          page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')));
    });

    test('R10-SOC-01: a fotografia das pendentes termina na mesma janela → o operador FICA na OS', () async {
      final gate = Completer<void>();
      final voice = Completer<void>();
      final nfse = NfseRepoMock();
      final invoice = InvoiceRepoMock();
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) async {
        await gate.future;
        return const Right(PagedResult.empty());
      });
      await slowVoiceDetail(nfse, invoice, voice);
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ServiceOrderViewRequested(7));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalPendingLoaded);
      gate.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      voice.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      expect(shownOf(states).last, isA<ServiceOrderDetailState>());
    });

    test('R10-SOC-03: o ato no detalhe FALHA depois que a tela virou lista (página recriada) → o desfecho aparece e o detalhe NÃO volta por cima', () async {
      final slow = Completer<Either<Failure, Unit>>();
      when(() => repo.getById(any())).thenAnswer((_) async => const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'A')));
      when(() => repo.itemDelete(any(), any())).thenAnswer((_) => slow.future);
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(7));
      await detail;
      bloc.add(const ServiceOrderItemRemoveRequested(orderId: 7, itemId: 1));
      await Future<void>.delayed(Duration.zero);
      final list = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                       // a página recriada (D-F160) pede a lista
      await list;
      final failed = bloc.stream.firstWhere((s) => s is ServiceOrderActionFailure);
      slow.complete(const Left(Failure(message: 'busy', statusCode: 409)));
      await failed;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await bloc.close();
      expect(shownOf(states).last, isA<ServiceOrderListState>());
    });

    test('R10-SOC-03: o ato no detalhe dá CERTO depois que um lote foi confirmado por cima dele → o detalhe não ressuscita sobre o lote e o fim do lote recarrega a lista', () async {
      final slow = Completer<Either<Failure, Unit>>();
      final gate = Completer<void>();
      when(() => repo.getById(any())).thenAnswer((_) async => const Right(ServiceOrderFull(id: 7, customerId: 1, status: 'A')));
      when(() => repo.itemDelete(any(), any())).thenAnswer((_) => slow.future);
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        await gate.future;
        return Right(_reportFor(inv.positionalArguments[0] as List<int>));
      });
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(7));
      await detail;
      bloc.add(const ServiceOrderItemRemoveRequested(orderId: 7, itemId: 1));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: _ids(3), input: _input));           // o lote confirmado por cima do detalhe
      await Future<void>.delayed(const Duration(milliseconds: 5));
      slow.complete(const Right(unit));                                                         // o ato termina com o lote no ar
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      gate.complete();
      await done;
      await sub.cancel();
      await bloc.close();
      verify(() => repo.getById(7)).called(1);                                                   // o ato NÃO releu o detalhe sobre o lote
      expect(states.whereType<ServiceOrderBatchInvoiceDone>(), hasLength(1));
      expect((shownOf(states).last as ServiceOrderListState).loading, isFalse);
    });
  });

  group('D-F187 (= Q-F195-SOC-01 (a)): os relatórios citam o número que a TELA mostra, nunca a chave interna', () {
    test('o relatório do lote de faturamento leva o Nº da OS de cada ordem (o da lista — `number ?? id`)', () async {
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => const Right(PagedResult(items: [
                ServiceOrderListItem(id: 8011, number: 7374, customerId: 1),
                ServiceOrderListItem(id: 8012, customerId: 1),
              ], page: 1, pageSize: 10, total: 2)));
      faturaTudo();
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final listed = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await listed;
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderBatchInvoiceDone);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: const [8011, 8012], input: _input));
      final report = await done as ServiceOrderBatchInvoiceDone;
      await sub.cancel();
      await bloc.close();
      expect(report.numbers, {8011: 7374, 8012: 8012}, reason: 'sem número, a OS mostra o id (como a lista)');
    });

    test('o lote FISCAL se identifica pelo nº da NOTA que a pendente fotografada traz', () async {
      final nfse = NfseRepoMock();
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) async => const Right(
          PagedResult(items: [ServiceOrderFiscalPending(invoiceId: 8011, number: '704')], page: 1, pageSize: 100, total: 1)));
      when(() => nfse.transmit(8011)).thenAnswer((_) async => const Right(ServiceOrderTransmitResult(invoiceId: 8011, attempt: 1, accessKey: 'K')));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse);
      final loaded = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalPendingLoaded);
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await loaded;
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([8011]));
      final report = await done as ServiceOrderFiscalBatchDone;
      await bloc.close();
      expect(report.noteNumbers, {8011: '704'});
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

  group('Q-BA16 (a) — critério recusado pela API', () {
    test('é DESCARTADO, o usuário é avisado e a lista recarrega com os demais', () async {
      final calls = <SearchCriteriaValues>[];
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        final c = inv.namedArguments[#criteria] as SearchCriteriaValues;
        calls.add(c);
        if (c.values.containsKey('totalValue')) {
          return const Left(Failure(message: 'x', statusCode: 422, code: 'SEARCH_CRITERION_INVALID',
              fields: [FailureField(field: 'totalValue', message: 'Valor da faixa inválido')]));
        }
        return const Right(PagedResult.empty());
      });
      final bloc = _bloc(repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final criteria = SearchCriteriaValues.from({
        'totalValue': const SearchRange(from: 1),
        'customer': const SearchLookupValue(id: 5, name: 'Acme'),
      });
      final done = bloc.stream.firstWhere(
          (s) => s is ServiceOrderListState && !s.loading && s.pageSize != null);
      bloc.add(ServiceOrderListRequested(criteria: criteria));
      final last = await done as ServiceOrderListState;
      await sub.cancel();
      await bloc.close();

      expect(calls.map((c) => c.values.keys.toList()), [
        ['totalValue', 'customer'],
        ['customer'],
      ]);
      expect(last.criteria.values.keys, ['customer']);
      final warned = states.whereType<ServiceOrderActionFailure>().single;
      expect(warned.failure.message, 'search.criterionRemoved');
      expect(warned.failure.fields.single.field, 'totalValue');
    });
  });
}
