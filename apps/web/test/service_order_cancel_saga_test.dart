// F2b — o cancelamento da nota da OS como SAGA (D-F139 = Q-F147 (a), Valdo
// 2026-10-13) e as duas APIs com contratos separados (D-F4). O que este teste
// fixa:
// (1) a ORDEM é do app (D-F28): com NFS-e autorizada o fisco fala PRIMEIRO e
//     só com o "ok" dele a nota é cancelada no ERP; recusa/desfecho
//     desconhecido no fisco NUNCA chega ao ERP;
// (2) retomada por DERIVAÇÃO: o fisco cancelou e a nota não → a falha diz
//     `authorityCancelled` (a tela relê o efeito `apply` e oferece "Aplicar o
//     cancelamento na nota" = a mesma saga sem o fisco);
// (3) o bloc: 1º passo SEMPRE o plano (one-shot); desfecho desconhecido no
//     fisco = aviso "consulte" + relê (nunca "não aconteceu"); a situação que
//     mudou (INVOICE_NOT_CANCELLABLE) = aviso + relê; sucesso relê e mostra os
//     avisos do fisco; duplo-clique não dispara duas sagas;
// (4) os contratos dos datasources: nfse-api `/v1/nfse/invoices/...` (a lista
//     de pendentes com `interfaceKey=service-orders`) × ERP `/api/billing/*`.

import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_invoice_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_nfse_datasource.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

import 'support/service_order_bloc_factory.dart';

const _orderId = 7374;
const _reason = 'Serviço não prestado no mês';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');
const _cancelled = ServiceOrderFull(id: _orderId, customerId: 1, status: 'C');
const _local = ServiceOrderInvoiceCancelResult(orderId: _orderId, invoiceNumber: '704', event: 3);
const _atFisco = ServiceOrderFiscalCancelResult(invoiceId: _orderId, warnings: ['Evento arquivado com atraso']);
const _authorizedVoice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);

/// O plano em que SÓ a NFS-e autorizada impede (a saga pode ir ao fisco — D-F149).
const _onlyAuthority = ServiceOrderCancelPlan(orderId: _orderId, fiscalRecord: true, blocks: [
  CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
]);

/// Cliente de mentira que grava as chamadas — serve às DUAS APIs.
mixin _Recorder on ProductApiClient {
  final calls = <String>[];
  Map<String, dynamic> reply = const {'ok': true, 'data': <String, dynamic>{}};

  @override
  Future<Map<String, dynamic>> get(String path) async {
    calls.add('GET $path');
    return reply;
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? overrideToken}) async {
    calls.add('POST $path $body');
    return reply;
  }
}

class _ErpClient extends ApiClient with _Recorder {}

class _NfseClient extends NfseApiClient with _Recorder {}

void main() {
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;

  setUp(() {
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    // D-F149: com atAuthority a saga RELÊ o plano antes do fisco
    when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Right(_onlyAuthority));
  });

  group('saga (usecase de composição)', () {
    test('D-F149: o plano relido antes do fisco MUDOU (título baixado no meio) → a saga NÃO vai ao fisco nem ao ERP', () async {
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Right(ServiceOrderCancelPlan(orderId: _orderId, blocks: [
            CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
            CancelPlanBlock(field: 'title', message: 'Título 7650/1 tem baixa', ref: '7650/1'),
          ])));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);

      expect(r.fold((f) => [f.stage, f.failure.code], (_) => null), [CancelSagaStage.plan, FiscalCodes.cancelPlanChanged]);
      verifyNever(() => nfse.cancel(any(), any()));
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('D-F149: o plano relido não se lê (503 da voz) → nada é feito (stage plan)', () async {
      const down = Failure(message: 'Situação no fisco indisponível', statusCode: 503, code: FiscalCodes.voiceUnavailable);
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Left(down));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);

      expect(r, const Left<CancelSagaFailure, ServiceOrderCancelOutcome>(CancelSagaFailure(stage: CancelSagaStage.plan, failure: down)));
      verifyNever(() => nfse.cancel(any(), any()));
    });

    test('sem o fisco ("Aplicar o cancelamento na nota") o plano NÃO é relido pela saga (a tela acabou de lê-lo; o POST refaz)', () async {
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_local));

      await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: false);

      verifyNever(() => invoice.cancelPlan(any()));
    });

    test('atAuthority: o fisco PRIMEIRO, depois a nota; avisos do fisco no desfecho', () async {
      final order = <String>[];
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async {
        order.add('fisco');
        return const Right(_atFisco);
      });
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async {
        order.add('nota');
        return const Right(_local);
      });

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);

      expect(order, ['fisco', 'nota']);
      final outcome = r.getOrElse(() => throw StateError('esperava Right'));
      expect(outcome.result, _local);
      expect(outcome.warnings, ['Evento arquivado com atraso']);
    });

    test('recusa do fisco: a nota NUNCA é chamada (stage authority)', () async {
      const refused = Failure(message: 'E1235 prazo', statusCode: 422, code: FiscalCodes.dpsRejected);
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(refused));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);

      expect(r, const Left<CancelSagaFailure, ServiceOrderCancelOutcome>(
          CancelSagaFailure(stage: CancelSagaStage.authority, failure: refused)));
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('desfecho DESCONHECIDO no fisco (rede caiu): também nunca chega ao ERP', () async {
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(NetworkFailure()));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);

      expect(r.fold((f) => f.stage, (_) => null), CancelSagaStage.authority);
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('o fisco cancelou e a nota não: falha da NOTA com authorityCancelled (retomada por derivação)', () async {
      const busy = Failure(message: 'Caixa fechado', statusCode: 409, code: 'CASHIER_CLOSED');
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_atFisco));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(busy));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);

      expect(r, const Left<CancelSagaFailure, ServiceOrderCancelOutcome>(
          CancelSagaFailure(stage: CancelSagaStage.invoice, failure: busy, authorityCancelled: true)));
    });

    test('sem o fisco (nota sem registro, ou "Aplicar o cancelamento na nota"): só o ERP', () async {
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_local));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: false);

      expect(r.isRight(), isTrue);
      verifyNever(() => nfse.cancel(any(), any()));
    });

    test('falha da nota sem o fisco: authorityCancelled false', () async {
      const blocked = Failure(message: 'Título baixado', statusCode: 409, code: FiscalCodes.invoiceCancelBlocked);
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(blocked));

      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: false);

      expect(r.fold((f) => f.authorityCancelled, (_) => null), isFalse);
    });
  });

  group('bloc — plano primeiro, saga depois, sempre relendo', () {
    late ServiceOrderRepoMock repo;

    setUp(() {
      repo = ServiceOrderRepoMock();
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Right(_authorizedVoice));
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
    });

    Future<ServiceOrderBloc> opened() async {
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(_orderId));
      await shown;
      return bloc;
    }

    /// Dispara [event] e coleta os estados até o detalhe voltar (saving false).
    Future<List<ServiceOrderState>> run(ServiceOrderBloc bloc, ServiceOrderEvent event) async {
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && !s.saving);
      bloc.add(event);
      await done;
      await sub.cancel();
      await bloc.close();
      return states;
    }

    test('ServiceOrderCancelFlowRequested: lê o PLANO e entrega no one-shot (nada cancelado)', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      const plan = ServiceOrderCancelPlan(orderId: _orderId, blocks: [
        CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
      ]);
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Right(plan));

      final bloc = await opened();
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final ready = bloc.stream.firstWhere((s) => s is ServiceOrderCancelPlanReady);
      bloc.add(const ServiceOrderCancelFlowRequested(_orderId));
      await ready;
      await sub.cancel();
      await bloc.close();

      expect(states.whereType<ServiceOrderCancelPlanReady>().single.plan.onlyAuthorityStands, isTrue);
      verifyNever(() => nfse.cancel(any(), any()));
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('plano indisponível (503 voz) vai à ponte; nada é cancelado', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Left(
          Failure(message: 'Situação no fisco indisponível', statusCode: 503, code: FiscalCodes.voiceUnavailable)));

      final states = await run(await opened(), const ServiceOrderCancelFlowRequested(_orderId));

      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code, FiscalCodes.voiceUnavailable);
      expect(states.whereType<ServiceOrderCancelPlanReady>(), isEmpty);
    });

    test('sucesso com o fisco: mensagem com o nº, avisos do fisco e o detalhe RELIDO (status vem do servidor)', () async {
      final orders = [_order, _cancelled];
      when(() => repo.getById(_orderId)).thenAnswer((_) async => Right(orders.removeAt(0)));
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_atFisco));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_local));

      final states = await run(await opened(),
          const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));

      final ok = states.whereType<ServiceOrderActionSuccess>().single;
      expect(ok.messageKey, 'forms.serviceOrder.invoiceCancelled');
      expect(ok.args, ['704']);
      expect(states.whereType<ServiceOrderFiscalWarnings>().single.warnings, ['Evento arquivado com atraso']);
      expect((states.last as ServiceOrderDetailState).order.status, 'C');
    });

    test('desfecho desconhecido no fisco: aviso "consulte" + relê — nunca falha seca, nunca ERP', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(
          Failure(message: 'Fisco fora', statusCode: 503, code: FiscalCodes.authorityUnavailable)));

      final states = await run(await opened(),
          const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));

      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown');
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
      verify(() => repo.getById(_orderId)).called(2);
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('o fisco cancelou e a nota não: aviso "aplicar na nota" + relê (o efeito apply aparece na seção)', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_atFisco));
      when(() => invoice.cancel(_orderId, _reason))
          .thenAnswer((_) async => const Left(Failure(message: 'Abra o caixa', statusCode: 409)));
      final effects = [const ServiceOrderFiscalEffect(), const ServiceOrderFiscalEffect(effect: FiscalEffect.apply)];
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => Right(effects.removeAt(0)));

      final states = await run(await opened(),
          const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));

      final notice = states.whereType<ServiceOrderFiscalNotice>().single;
      expect(notice.messageKey, 'forms.serviceOrder.fiscalLocalCancelPending');
      expect(notice.detail, 'Abra o caixa');
      expect((states.last as ServiceOrderDetailState).effect!.effect, FiscalEffect.apply);
    });

    test('D-F149 no bloc: o plano relido mudou → aviso "a situação mudou" + relê; o fisco nunca é chamado', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Right(ServiceOrderCancelPlan(orderId: _orderId)));

      final states = await run(await opened(),
          const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));

      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalSituationChanged');
      verifyNever(() => nfse.cancel(any(), any()));
      verify(() => repo.getById(_orderId)).called(2);
    });

    test('a situação mudou (INVOICE_NOT_CANCELLABLE): aviso próprio + relê', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(
          Failure(message: 'Nota já cancelada', statusCode: 409, code: FiscalCodes.invoiceNotCancellable)));

      final states = await run(await opened(),
          const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: false));

      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalSituationChanged');
      verify(() => repo.getById(_orderId)).called(2);
    });

    test('duplo-clique: a 2ª confirmação enquanto a 1ª roda é IGNORADA (uma saga só)', () async {
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      final gate = Completer<void>();
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async {
        await gate.future;
        return const Right(_atFisco);
      });
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_local));
      final bloc = await opened();
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && !s.saving);

      const confirm = ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true);
      bloc.add(confirm);
      await Future<void>.delayed(Duration.zero);
      bloc.add(confirm);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await done;
      await bloc.close();

      verify(() => nfse.cancel(_orderId, _reason)).called(1);
      verify(() => invoice.cancel(_orderId, _reason)).called(1);
    });
  });

  group('contratos dos datasources (duas APIs, nunca cruzam)', () {
    test('nfse-api: rotas /v1/nfse/invoices/... e a lista de pendentes filtrada no SERVIDOR', () async {
      final client = _NfseClient();
      final ds = ServiceOrderNfseDatasourceImpl(client: client);

      await ds.getView(10);
      await ds.transmit(10);
      await ds.refresh(10);
      await ds.reconfirm(10);
      await ds.cancel(10, _reason);
      await ds.xml(10);
      await ds.danfse(10);
      client.reply = const {'ok': true, 'data': [], 'page': 2, 'pageSize': 100, 'total': 0};
      await ds.pending(page: 2);

      expect(client.calls, [
        'GET /v1/nfse/invoices/10',
        'POST /v1/nfse/invoices/10/transmit {}',
        'POST /v1/nfse/invoices/10/refresh {}',
        'POST /v1/nfse/invoices/10/reconfirm {}',
        'POST /v1/nfse/invoices/10/cancel {reason: $_reason}',
        'GET /v1/nfse/invoices/10/xml',
        'GET /v1/nfse/invoices/10/danfse',
        'GET /v1/nfse/invoices/pending?interfaceKey=service-orders&page=2&pageSize=100',
      ]);
    });

    test('ERP: plano, efeito, cancelar e manter pela /api/billing/*', () async {
      final client = _ErpClient();
      final ds = ServiceOrderInvoiceDatasourceImpl(client: client);

      await ds.cancelPlan(10);
      await ds.fiscalEffect(10);
      await ds.cancel(10, _reason);
      await ds.cancelWaiver(10, _reason);

      expect(client.calls, [
        'GET /api/billing/10/cancel-plan',
        'GET /api/billing/10/fiscal-effect',
        'POST /api/billing/cancel {orderId: 10, reason: $_reason}',
        'POST /api/billing/cancel-waiver {orderId: 10, reason: $_reason}',
      ]);
    });
  });
}
