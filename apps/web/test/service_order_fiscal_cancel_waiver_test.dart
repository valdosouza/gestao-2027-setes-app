// D-F67 (Valdo 2026-10-10) — "Manter a nota" na seção "No fisco" da OS: a
// NFS-e foi cancelada POR SUBSTITUIÇÃO no fisco (e105102, feito no portal) e o
// humano decide NÃO cancelar a nota no ERP. F2b (D-F139/D-F142): a decisão é
// um FATO DO ERP — vai pelo datasource dos fatos da nota (setes-api
// `/api/billing/*`), nunca pela nfse-api; o "cabe decidir" é o EFEITO
// `decide` que o ERP devolve. O que este teste fixa:
// (1) o contrato do cliente — POST /api/billing/cancel-waiver {orderId,
//     reason} e o parse de `data`;
// (2) a falha da API vira Left intacta (código + status) para a ponte;
// (3) o fluxo do bloc — sucesso recarrega o detalhe (voz + efeito relidos),
//     `alreadyWaived` tem mensagem própria, 409
//     INVOICE_CANCEL_WAIVER_NOT_APPLICABLE recarrega o detalhe (a situação
//     mudou fora da tela), outras falhas devolvem o detalhe como estava, e o
//     duplo-clique não manda duas decisões.

import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_invoice_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_invoice_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

import 'support/service_order_bloc_factory.dart';

/// ApiClient de mentira: grava o POST e devolve a resposta (ou lança a
/// [Failure] que o ApiClient real lançaria no 4xx).
class _FakeClient extends ApiClient {
  _FakeClient({this.response = const {}, this.failure});

  final Map<String, dynamic> response;
  final Failure? failure;
  final posts = <(String, Map<String, dynamic>)>[];

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? overrideToken}) async {
    posts.add((path, body));
    final f = failure;
    if (f != null) throw f;
    return response;
  }
}

const _orderId = 7223;
const _reason = 'Substituta emitida no portal pelo contador';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');

/// A voz do fisco (nfse-api): cancelada por substituição, com a substituta.
const _substitutedVoice = ServiceOrderFiscalView(
  state: NfseState.cancelled,
  currentAttempt: 1,
  substitution: ServiceOrderFiscalSubstitution(substituteAccessKey: 'SUB'),
);

/// O efeito no ERP: o humano decide.
const _decide = ServiceOrderFiscalEffect(effect: FiscalEffect.decide);

/// O efeito depois da decisão: nada a fazer + a decisão vigente.
const _kept = ServiceOrderFiscalEffect(
  cancelWaiver: ServiceOrderFiscalCancelWaiver(
      accessKey: 'K1', reason: _reason, userId: 7, createdAt: '2026-10-10 15:42:00'),
);

void main() {
  group('datasource — contrato do POST (ERP, nunca a nfse-api)', () {
    test('POST /api/billing/cancel-waiver com {orderId, reason} e lê data', () async {
      final client = _FakeClient(response: {
        'ok': true,
        'data': {'orderId': _orderId, 'accessKey': 'K1', 'createdAt': '2026-10-10 15:42:00', 'alreadyWaived': false},
      });
      final ds = ServiceOrderInvoiceDatasourceImpl(client: client);

      final r = await ds.cancelWaiver(_orderId, _reason);

      expect(client.posts.single.$1, '/api/billing/cancel-waiver');
      expect(client.posts.single.$2, {'orderId': _orderId, 'reason': _reason});
      expect(r.orderId, _orderId);
      expect(r.accessKey, 'K1');
      expect(r.createdAt, '2026-10-10 15:42:00');
      expect(r.alreadyWaived, isFalse);
    });

    test('resposta sem o envelope (sem data) é FALHA técnica — nunca "decisão registrada" inventada (F2B-ADV-04)', () async {
      final ds = ServiceOrderInvoiceDatasourceImpl(client: _FakeClient(response: const {'ok': true}));
      await expectLater(ds.cancelWaiver(_orderId, _reason),
          throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.invalidResponse)));
    });

    test('409 da API chega INTACTO ao repositório como Left (ponte trata)', () async {
      const conflict = Failure(
          message: 'A nota não admite a decisão de manter',
          statusCode: 409,
          code: FiscalCodes.cancelWaiverNotApplicable);
      final repo = ServiceOrderInvoiceRepositoryImpl(
          datasource: ServiceOrderInvoiceDatasourceImpl(client: _FakeClient(failure: conflict)));

      final result = await repo.cancelWaiver(_orderId, _reason);

      expect(result, const Left<Failure, ServiceOrderCancelWaiverResult>(conflict));
    });
  });

  group('bloc — "Manter a nota"', () {
    late ServiceOrderRepoMock repo;
    late NfseRepoMock nfse;
    late InvoiceRepoMock invoice;

    setUp(() {
      repo = ServiceOrderRepoMock();
      nfse = NfseRepoMock();
      invoice = InvoiceRepoMock();
      when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Right(_substitutedVoice));
    });

    /// Abre o detalhe da OS faturada (o bloc guarda a OS, a voz e o efeito) e
    /// devolve o bloc pronto para a ação.
    Future<ServiceOrderBloc> opened() async {
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
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
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && !s.saving);
      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(orderId: _orderId, reason: _reason));
      await done;
      await sub.cancel();
      await bloc.close();
      return states;
    }

    test('sucesso: saving → mensagem → detalhe RECARREGADO com a decisão (efeito relido do ERP)', () async {
      final effects = [_decide, _kept];
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => Right(effects.removeAt(0)));
      when(() => invoice.cancelWaiver(_orderId, _reason))
          .thenAnswer((_) async => const Right(ServiceOrderCancelWaiverResult(orderId: _orderId)));

      final states = await keep(await opened());

      expect((states.first as ServiceOrderDetailState).saving, isTrue);
      expect(states.whereType<ServiceOrderActionSuccess>().single.messageKey, 'forms.serviceOrder.fiscalKeepDone');
      final last = states.last as ServiceOrderDetailState;
      expect(last.effect!.cancelWaiver!.reason, _reason);
      expect(last.effect!.effect, FiscalEffect.none, reason: 'decidido: não cabe decidir de novo');
      verify(() => invoice.cancelWaiver(_orderId, _reason)).called(1);
      verify(() => invoice.fiscalEffect(_orderId)).called(2);
      verify(() => nfse.getView(_orderId)).called(2);
      verifyNever(() => nfse.cancel(any(), any()));
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
    });

    test('alreadyWaived: mensagem própria (decisão já estava registrada)', () async {
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => const Right(_kept));
      when(() => invoice.cancelWaiver(_orderId, _reason)).thenAnswer(
          (_) async => const Right(ServiceOrderCancelWaiverResult(orderId: _orderId, alreadyWaived: true)));

      final states = await keep(await opened());

      expect(states.whereType<ServiceOrderActionSuccess>().single.messageKey, 'forms.serviceOrder.fiscalKeepAlready');
    });

    test('409 NOT_APPLICABLE: falha pela ponte E o detalhe recarrega (a situação mudou fora da tela)', () async {
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => const Right(_decide));
      when(() => invoice.cancelWaiver(_orderId, _reason)).thenAnswer((_) async => const Left(
          Failure(message: 'Nota já cancelada', statusCode: 409, code: FiscalCodes.cancelWaiverNotApplicable)));

      final states = await keep(await opened());

      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code, FiscalCodes.cancelWaiverNotApplicable);
      expect(states.whereType<ServiceOrderActionSuccess>(), isEmpty);
      verify(() => repo.getById(_orderId)).called(2);
      verify(() => invoice.fiscalEffect(_orderId)).called(2);
    });

    test('403 (sem CANCELAR): falha pela ponte e o detalhe volta como estava, sem nova consulta', () async {
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => const Right(_decide));
      when(() => invoice.cancelWaiver(_orderId, _reason))
          .thenAnswer((_) async => const Left(Failure(message: 'Sem privilégio', statusCode: 403)));

      final states = await keep(await opened());

      expect(states.whereType<ServiceOrderActionFailure>().single.failure.statusCode, 403);
      final last = states.last as ServiceOrderDetailState;
      expect(last.effect, _decide, reason: 'a decisão segue em aberto');
      expect(last.fiscal, _substitutedVoice);
      verify(() => repo.getById(_orderId)).called(1);
      verify(() => invoice.fiscalEffect(_orderId)).called(1);
    });

    test('duplo-clique: a 2ª decisão enquanto a 1ª roda é IGNORADA', () async {
      when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => const Right(_decide));
      final gate = Completer<void>();
      when(() => invoice.cancelWaiver(_orderId, _reason)).thenAnswer((_) async {
        await gate.future;
        return const Right(ServiceOrderCancelWaiverResult(orderId: _orderId));
      });
      final bloc = await opened();
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && !s.saving);

      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(orderId: _orderId, reason: _reason));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(orderId: _orderId, reason: _reason));
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await done;
      await bloc.close();

      verify(() => invoice.cancelWaiver(_orderId, _reason)).called(1);
    });
  });
}
