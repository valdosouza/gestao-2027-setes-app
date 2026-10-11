// D-F67 (Valdo 2026-10-10) — "Manter a nota" na seção "No fisco" da OS: a
// NFS-e foi cancelada POR SUBSTITUIÇÃO no fisco (e105102, feito no portal) e o
// humano decide NÃO cancelar a nota no ERP. O que este teste fixa:
// (1) o contrato do cliente — POST /api/billing/cancel-waiver {orderId,
//     reason} e o parse de `data`;
// (2) a falha da API vira Left intacta (código + status) para a ponte;
// (3) o fluxo do bloc — sucesso recarrega o detalhe (a decisão aparece na
//     seção), `alreadyWaived` tem mensagem própria, 409
//     INVOICE_CANCEL_WAIVER_NOT_APPLICABLE recarrega o detalhe (a situação
//     mudou fora da tela), outras falhas devolvem o detalhe como estava, e o
//     duplo-clique não manda duas decisões.

import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_fiscal_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_fiscal_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
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
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_waive_cancel.dart';
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

/// ApiClient de mentira: grava o POST e devolve a resposta (ou lança a
/// [Failure] que o ApiClient real lançaria no 4xx).
class _FakeClient extends ApiClient {
  _FakeClient({this.response = const {}, this.failure});

  final Map<String, dynamic> response;
  final Failure? failure;
  final posts = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {String? overrideToken}) async {
    posts.add((path, body));
    final f = failure;
    if (f != null) throw f;
    return response;
  }
}

class _RepoMock extends Mock implements ServiceOrderRepository {}

class _FiscalRepoMock extends Mock implements ServiceOrderFiscalRepository {}

ServiceOrderBloc _bloc(
        ServiceOrderRepository repo, ServiceOrderFiscalRepository fiscal) =>
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
      fiscalWaiveCancel: ServiceOrderFiscalWaiveCancel(repository: fiscal),
    );

const _orderId = 7223;
const _reason = 'Substituta emitida no portal pelo contador';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');

const _substituted = ServiceOrderFiscalView(
  pendingEffects: 1,
  substitution: ServiceOrderFiscalSubstitution(substituteAccessKey: 'SUB'),
);

const _kept = ServiceOrderFiscalView(
  substitution:
      ServiceOrderFiscalSubstitution(substituteAccessKey: 'SUB', waived: true),
  cancelWaiver: ServiceOrderFiscalCancelWaiver(
      accessKey: 'K1', reason: _reason, userId: 7,
      createdAt: '2026-10-10 15:42:00'),
);

void main() {
  group('datasource — contrato do POST', () {
    test('POST /api/billing/cancel-waiver com {orderId, reason} e lê data',
        () async {
      final client = _FakeClient(response: {
        'ok': true,
        'data': {
          'orderId': _orderId,
          'accessKey': 'K1',
          'createdAt': '2026-10-10 15:42:00',
          'alreadyWaived': false,
        },
      });
      final ds = ServiceOrderFiscalDatasourceImpl(client: client);

      final r = await ds.cancelWaiver(_orderId, _reason);

      expect(client.posts.single.$1, '/api/billing/cancel-waiver');
      expect(client.posts.single.$2, {'orderId': _orderId, 'reason': _reason});
      expect(r.orderId, _orderId);
      expect(r.accessKey, 'K1');
      expect(r.createdAt, '2026-10-10 15:42:00');
      expect(r.alreadyWaived, isFalse);
    });

    test('resposta sem data não quebra (orderId 0, não mantida antes)',
        () async {
      final ds = ServiceOrderFiscalDatasourceImpl(
          client: _FakeClient(response: const {'ok': true}));
      final r = await ds.cancelWaiver(_orderId, _reason);
      expect(r.orderId, 0);
      expect(r.alreadyWaived, isFalse);
    });

    test('409 da API chega INTACTO ao repositório como Left (ponte trata)',
        () async {
      const conflict = Failure(
          message: 'A nota não admite a decisão de manter',
          statusCode: 409,
          code: fiscalCancelWaiverNotApplicable);
      final repo = ServiceOrderFiscalRepositoryImpl(
          datasource: ServiceOrderFiscalDatasourceImpl(
              client: _FakeClient(failure: conflict)));

      final result = await repo.cancelWaiver(_orderId, _reason);

      expect(result, const Left<Failure, ServiceOrderCancelWaiverResult>(conflict));
    });
  });

  group('bloc — "Manter a nota"', () {
    late _RepoMock repo;
    late _FiscalRepoMock fiscal;

    setUp(() {
      repo = _RepoMock();
      fiscal = _FiscalRepoMock();
      when(() => repo.getById(_orderId))
          .thenAnswer((_) async => const Right(_order));
    });

    /// Abre o detalhe da OS faturada (o bloc guarda a OS e a visão fiscal) e
    /// devolve o bloc pronto para a ação.
    Future<ServiceOrderBloc> opened() async {
      final bloc = _bloc(repo, fiscal);
      final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(_orderId));
      await shown;
      return bloc;
    }

    /// Dispara a decisão e coleta os estados até o detalhe voltar a ficar
    /// disponível (saving false).
    Future<List<ServiceOrderState>> keep(ServiceOrderBloc bloc) async {
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final done = bloc.stream.firstWhere(
          (s) => s is ServiceOrderDetailState && !s.saving);
      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(
          orderId: _orderId, reason: _reason));
      await done;
      await sub.cancel();
      await bloc.close();
      return states;
    }

    test('sucesso: saving → mensagem → detalhe RECARREGADO com a decisão',
        () async {
      var views = [_substituted, _kept];
      when(() => fiscal.getView(_orderId))
          .thenAnswer((_) async => Right(views.removeAt(0)));
      when(() => fiscal.cancelWaiver(_orderId, _reason)).thenAnswer((_) async =>
          const Right(ServiceOrderCancelWaiverResult(orderId: _orderId)));

      final states = await keep(await opened());

      expect((states.first as ServiceOrderDetailState).saving, isTrue);
      expect(states.whereType<ServiceOrderActionSuccess>().single.messageKey,
          'forms.serviceOrder.fiscalKeepDone');
      final last = states.last as ServiceOrderDetailState;
      expect(last.fiscal!.cancelWaiver!.reason, _reason);
      expect(last.fiscal!.canWaiveCancel, isFalse);
      verify(() => fiscal.cancelWaiver(_orderId, _reason)).called(1);
      verify(() => fiscal.getView(_orderId)).called(2);
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
    });

    test('alreadyWaived: mensagem própria (decisão já estava registrada)',
        () async {
      when(() => fiscal.getView(_orderId))
          .thenAnswer((_) async => const Right(_kept));
      when(() => fiscal.cancelWaiver(_orderId, _reason)).thenAnswer((_) async =>
          const Right(ServiceOrderCancelWaiverResult(
              orderId: _orderId, alreadyWaived: true)));

      final states = await keep(await opened());

      expect(states.whereType<ServiceOrderActionSuccess>().single.messageKey,
          'forms.serviceOrder.fiscalKeepAlready');
    });

    test('409 NOT_APPLICABLE: falha pela ponte E o detalhe recarrega (a situação mudou fora da tela)',
        () async {
      when(() => fiscal.getView(_orderId))
          .thenAnswer((_) async => const Right(_substituted));
      when(() => fiscal.cancelWaiver(_orderId, _reason)).thenAnswer((_) async =>
          const Left(Failure(
              message: 'Nota já cancelada',
              statusCode: 409,
              code: fiscalCancelWaiverNotApplicable)));

      final states = await keep(await opened());

      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code,
          fiscalCancelWaiverNotApplicable);
      expect(states.whereType<ServiceOrderActionSuccess>(), isEmpty);
      verify(() => repo.getById(_orderId)).called(2);
      verify(() => fiscal.getView(_orderId)).called(2);
    });

    test('403 (sem CANCELAR): falha pela ponte e o detalhe volta como estava, sem nova consulta',
        () async {
      when(() => fiscal.getView(_orderId))
          .thenAnswer((_) async => const Right(_substituted));
      when(() => fiscal.cancelWaiver(_orderId, _reason)).thenAnswer((_) async =>
          const Left(Failure(message: 'Sem privilégio', statusCode: 403)));

      final states = await keep(await opened());

      expect(states.whereType<ServiceOrderActionFailure>().single.failure.statusCode,
          403);
      final last = states.last as ServiceOrderDetailState;
      expect(last.fiscal, _substituted, reason: 'a decisão segue em aberto');
      verify(() => repo.getById(_orderId)).called(1);
      verify(() => fiscal.getView(_orderId)).called(1);
    });

    test('duplo-clique: a 2ª decisão enquanto a 1ª roda é IGNORADA', () async {
      when(() => fiscal.getView(_orderId))
          .thenAnswer((_) async => const Right(_substituted));
      final gate = Completer<void>();
      when(() => fiscal.cancelWaiver(_orderId, _reason)).thenAnswer((_) async {
        await gate.future;
        return const Right(ServiceOrderCancelWaiverResult(orderId: _orderId));
      });
      final bloc = await opened();
      final done = bloc.stream.firstWhere(
          (s) => s is ServiceOrderDetailState && !s.saving);

      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(
          orderId: _orderId, reason: _reason));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(
          orderId: _orderId, reason: _reason));
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await done;
      await bloc.close();

      verify(() => fiscal.cancelWaiver(_orderId, _reason)).called(1);
    });
  });
}
