// GATE ADVERSARIAL independente do DELTA da Rodada 14 da F2a/F2b (setes-app) — alvo: `9a5d2a8..822fdf9` (branch f2b):
// D-F193 (`_rereadAfterAct`: a releitura da OS ABERTA é a de um ATO — `act: true`, morre com o lote confirmado por cima; a da OS A
// CAMINHO por escolha do operador segue como pedido "a caminho" e vence o lote; nos dois o contador sobe), D-F194 (o plano do
// cancelamento abre também com a MESMA OS a caminho — `_showsOrder`), R13-SOC-03 (a cadeia de dois diálogos guardada pelo bloc vivo).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R14-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_r14_gate_test.dart
//   - `[FATO R14-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada ACHADO.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail (molde dos gates R9–R13).

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

/// Os NÚMEROS que a tela mostra PERMUTAM os ids (o número de cada OS é o id de OUTRA) — o molde do gate R13 (R12-ADV-06).
const _newId = 77;
const _aId = 7374;
const _bId = 8001;
const _numberOf = {_newId: 8001, _aId: 77, _bId: 7374};
const _newOrder = ServiceOrderFull(id: _newId, number: 8001, customerId: 5);
const _a = ServiceOrderFull(id: _aId, number: 77, customerId: 1, status: 'F');
const _b = ServiceOrderFull(id: _bId, number: 7374, customerId: 2, status: 'F');
const _aVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
const _bVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 3);
const _aEffect = ServiceOrderFiscalEffect();
const _bEffect = ServiceOrderFiscalEffect(invoiceCancelled: true);
const _aNote = '9001';

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

PagedResult<ServiceOrderListItem> _page(List<int> ids) => PagedResult(items: [
      for (final id in ids) ServiceOrderListItem(id: id, number: _numberOf[id], customerId: 1, status: id == _newId ? 'A' : 'F'),
    ], page: 1, pageSize: 10, total: ids.length);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState? _shownOrNull(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
ServiceOrderState _shown(List<ServiceOrderState> states) => _shownOrNull(states)!;

/// O one-shot de DESFECHO de um ato (os seis que levam a identidade da OS) — (é desfecho?, o número que leva).
(bool, int?) _outcome(ServiceOrderState s) => switch (s) {
      ServiceOrderActionSuccess(:final orderNumber) => (true, orderNumber),
      ServiceOrderActionFailure(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalNotice(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalWarnings(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalXmlReady(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalDanfseReady(:final orderNumber) => (true, orderNumber),
      _ => (false, null),
    };

/// Uma resposta EM VOO do fuzzer. [tag]: de onde a chamada nasceu (o 1º passo do cancelamento × a releitura do plano pela saga; o POST
/// de QUAL "Abrir OS"; o ato nascido com a OS a caminho — D-F194).
class _Flight {
  _Flight(this.label, this.finish, this.tag);
  final String label;
  final void Function(bool ok) finish;
  final String tag;
  int? get os => int.tryParse(label.split(' ').last);
  String get kind => label.split(' ').first;
}

class _Dialog {
  _Dialog(this.decision);
  final ServiceOrderEvent decision;
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
  });

  /// Cada leitura de uma OS (e da voz dela) pega o PRÓXIMO futuro da fila (ou a resposta imediata de sempre).
  late Map<int, List<Completer<Either<Failure, ServiceOrderFull>>>> getQueue;
  late Map<int, List<Completer<Either<Failure, ServiceOrderFiscalView>>>> voiceQueue;
  late Map<int, int> getCalls;

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    getQueue = {};
    voiceQueue = {};
    getCalls = {};
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => Right(_page([_newId, _aId, _bId])));
    const orderOf = {_newId: _newOrder, _aId: _a, _bId: _b};
    for (final id in orderOf.keys) {
      when(() => repo.getById(id)).thenAnswer((_) {
        getCalls[id] = (getCalls[id] ?? 0) + 1;
        final q = getQueue[id];
        if (q != null && q.isNotEmpty) return q.removeAt(0).future;
        return Future.value(Right(orderOf[id]!));
      });
    }
    const voiceOf = {_aId: _aVoice, _bId: _bVoice};
    for (final id in voiceOf.keys) {
      when(() => nfse.getView(id)).thenAnswer((_) {
        final q = voiceQueue[id];
        if (q != null && q.isNotEmpty) return q.removeAt(0).future;
        return Future.value(Right(voiceOf[id]!));
      });
    }
    when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) async => const Right(_aEffect));
    when(() => invoice.fiscalEffect(_bId)).thenAnswer((_) async => const Right(_bEffect));
    when(() => repo.open(5)).thenAnswer((_) async => const Right(_newId));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>)> start() async {
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final states = <ServiceOrderState>[];
    final sub = bloc.stream.listen(states.add);
    return (bloc, states, sub);
  }

  Completer<Either<Failure, ServiceOrderFull>> parkNextGet(int id) {
    final c = Completer<Either<Failure, ServiceOrderFull>>();
    (getQueue[id] ??= []).add(c);
    return c;
  }

  Completer<Either<Failure, ServiceOrderFiscalView>> parkNextVoice(int id) {
    final c = Completer<Either<Failure, ServiceOrderFiscalView>>();
    (voiceQueue[id] ??= []).add(c);
    return c;
  }

  // ---------------------------------------------------------------------
  // 1. R14-ADV-01 — D-F194 abre o plano com a OS A CAMINHO: o ato confirmado ANTES de ela chegar nasce SEM `saving`
  // ---------------------------------------------------------------------
  group('R14-ADV-01 — o ato nascido com a MESMA OS a caminho (a porta nova da D-F194)', () {
    /// "Cancelar nota" na OS A (o plano demora); a página recriada (cruzar 1100 px — D-F160); o operador reabre A — A CAMINHO (a voz da
    /// nfse-api é lenta); o plano chega e, pela D-F194, o diálogo abre POR CIMA da lista em loading; o operador confirma o motivo antes
    /// de a OS chegar — o cancelamento começa com o `_detail` nulo (o `_beginDetailAct` não marca nada).
    Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>, Completer<Either<Failure, ServiceOrderInvoiceCancelResult>>)>
        cancelBornOnTheWayThenLands() async {
      final plan = Completer<Either<Failure, ServiceOrderCancelPlan>>();
      when(() => invoice.cancelPlan(_aId)).thenAnswer((_) => plan.future);
      final local = Completer<Either<Failure, ServiceOrderInvoiceCancelResult>>();
      when(() => invoice.cancel(_aId, any())).thenAnswer((_) => local.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderCancelFlowRequested(_aId));                              // "Cancelar nota" — o plano demora
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      final onTheWay = parkNextGet(_aId);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // reabre A — a caminho
      await pumpEventQueue(times: 20);
      plan.complete(const Right(ServiceOrderCancelPlan(orderId: _aId, cancellable: true)));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderCancelPlanReady>().single.plan.orderId, _aId, reason: 'D-F194: o diálogo abre');
      expect((_shown(states) as ServiceOrderListState).loading, isTrue, reason: 'o diálogo abriu por cima da lista em loading');
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _aId, reason: 'motivo', atAuthority: false));   // confirma ANTES de A chegar
      await pumpEventQueue(times: 20);
      verify(() => invoice.cancel(_aId, 'motivo')).called(1);
      onTheWay.complete(const Right(_a));                                                  // A chega com o cancelamento no ar
      await pumpEventQueue(times: 20);
      return (bloc, states, sub, local);
    }

    test('[FATO R14-ADV-01] a OS A chega SEM `saving` com o cancelamento DELA no ar (os botões reabrem — "Cancelar nota", "Consultar"…); o 2º "Cancelar nota" do operador pede o plano, abre o diálogo, o operador digita o motivo DE NOVO e a decisão é DESCARTADA em silêncio pela trava por nota (D-F183) — nenhuma chamada, nenhum one-shot; o desfecho do 1º chega depois, sem prefixo (a tela é a OS dele)', () async {
      final plan2 = Completer<Either<Failure, ServiceOrderCancelPlan>>();
      final (bloc, states, sub, local) = await cancelBornOnTheWayThenLands();
      final landed = _shown(states) as ServiceOrderDetailState;
      expect([landed.order.id, landed.saving, local.isCompleted], [_aId, false, false],
          reason: 'A chegou sem saving com o cancelamento dela em voo');
      when(() => invoice.cancelPlan(_aId)).thenAnswer((_) => plan2.future);
      bloc.add(const ServiceOrderCancelFlowRequested(_aId));                              // o botão está aberto: o 2º "Cancelar nota"
      await pumpEventQueue(times: 20);
      plan2.complete(const Right(ServiceOrderCancelPlan(orderId: _aId, cancellable: true)));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderCancelPlanReady>(), hasLength(2), reason: 'o 2º diálogo abre');
      final at = states.length;
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _aId, reason: 'motivo de novo', atAuthority: false));
      await pumpEventQueue(times: 20);
      verifyNever(() => invoice.cancel(_aId, 'motivo de novo'));
      expect(states.sublist(at), isEmpty, reason: 'o 2º motivo digitado sumiu calado (a trava por nota)');
      local.complete(const Right(ServiceOrderInvoiceCancelResult(orderId: _aId, invoiceNumber: '9')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final done = states.whereType<ServiceOrderActionSuccess>().where((s) => s.messageKey == 'forms.serviceOrder.invoiceCancelled').single;
      expect([done.orderNumber, _shown(states).runtimeType, (_shown(states) as ServiceOrderDetailState).saving], [null, ServiceOrderDetailState, false]);
    });

    test('[ACHADO R14-ADV-01 LOW] o detalhe que CHEGA com um ato DELE em voo (nascido com a OS a caminho — a porta que a D-F194 abriu) sai em `saving` (os botões ficam travados até o desfecho) — "aberto" e "a caminho" são UM estado (R10-SOC-01), e o ato confirmado sobre a OS a caminho é um ato NO detalhe dela. Hoje a OS chega com os botões ABERTOS e uma 2ª decisão sobre a MESMA nota (motivo digitado) é descartada calada pela trava por nota. Correção possível: um contador por OS dos atos em voo, consultado onde o detalhe é EMITIDO (sem contar a releitura do próprio ato) — ou aceitar como a D-F191 (b)', () async {
      final (bloc, states, sub, local) = await cancelBornOnTheWayThenLands();
      final landed = _shown(states) as ServiceOrderDetailState;
      local.complete(const Right(ServiceOrderInvoiceCancelResult(orderId: _aId, invoiceNumber: '9')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([landed.order.id, landed.saving], [_aId, true], reason: 'o cancelamento de A estava no ar quando A chegou');
    }, skip: 'R14-ADV-01 LOW — LIMITE CONHECIDO pela D-F197 (= Q-F197-ADV-01 (a)): o comportamento desejado fica registrado, não implementado (a família da D-F191 (b)); o FATO acima fixa a semântica');

    test('[RESISTIU] D-F194 × a OS a caminho que FALHA: o diálogo já abriu por cima da lista; a leitura da OS falha (503) → a lista com a falha; a decisão confirmada DEPOIS vai (bloc vivo — D-F184), o desfecho leva o NÚMERO da A ("OS 77:" — a tela é a lista) e a A NÃO é relida; no repouso a lista livre', () async {
      final plan = Completer<Either<Failure, ServiceOrderCancelPlan>>();
      when(() => invoice.cancelPlan(_aId)).thenAnswer((_) => plan.future);
      when(() => invoice.cancel(_aId, any())).thenAnswer((_) async => const Right(ServiceOrderInvoiceCancelResult(orderId: _aId, invoiceNumber: '9')));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderCancelFlowRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      final onTheWay = parkNextGet(_aId);
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      plan.complete(const Right(ServiceOrderCancelPlan(orderId: _aId, cancellable: true)));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderCancelPlanReady>(), hasLength(1));
      onTheWay.complete(const Left(Failure(message: 'fora', statusCode: 503)));
      await pumpEventQueue(times: 20);
      expect([_shown(states).runtimeType, (_shown(states) as ServiceOrderListState).loading], [ServiceOrderListState, false]);
      final reads = getCalls[_aId];
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _aId, reason: 'motivo', atAuthority: false));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final done = states.whereType<ServiceOrderActionSuccess>().where((s) => s.messageKey == 'forms.serviceOrder.invoiceCancelled').single;
      expect([done.orderNumber, getCalls[_aId], _shown(states).runtimeType], [_numberOf[_aId], reads, ServiceOrderListState]);
    });

    test('[RESISTIU] D-F194 não abre o plano fora da OS que o pediu: com OUTRA OS (B) a caminho, e com a A a caminho SUPERADA por uma troca de aba (vale o último pedido) — nenhum diálogo, nenhum one-shot (a regra do R10-SOC-03)', () async {
      for (final superseding in <ServiceOrderEvent>[const ServiceOrderViewRequested(_bId), const ServiceOrderListRequested(status: 'F')]) {
        final plan = Completer<Either<Failure, ServiceOrderCancelPlan>>();
        when(() => invoice.cancelPlan(_aId)).thenAnswer((_) => plan.future);
        getQueue.clear();
        final (bloc, states, sub) = await start();
        bloc.add(const ServiceOrderViewRequested(_aId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderCancelFlowRequested(_aId));
        await pumpEventQueue();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 20);
        parkNextGet(_aId);
        bloc.add(const ServiceOrderViewRequested(_aId));                                 // A a caminho…
        await pumpEventQueue(times: 20);
        if (superseding is ServiceOrderViewRequested) parkNextGet(_bId);                  // B fica A CAMINHO
        bloc.add(superseding);                                                            // …superada por B a caminho / pela aba
        await pumpEventQueue(times: 20);
        final at = states.length;
        plan.complete(const Right(ServiceOrderCancelPlan(orderId: _aId, cancellable: true)));
        await pumpEventQueue(times: 20);
        expect(states.sublist(at), isEmpty, reason: 'o plano da A com ${superseding.runtimeType} por cima');
        // R15-SOC-04 (iii): o plano FOI pedido (e chegou) — o "nada emitido" acima não passa por vacuidade
        verify(() => invoice.cancelPlan(_aId)).called(1);
        await sub.cancel();
        await bloc.close();
      }
    });
  });

  // ---------------------------------------------------------------------
  // 2. D-F193 — sequências dirigidas no `_rereadAfterAct`
  // ---------------------------------------------------------------------
  group('D-F193 — a releitura do ato × o lote, a página recriada, dois atos', () {
    test('[RESISTIU] a releitura da OS ABERTA (`act: true`) morre com o lote confirmado por cima mesmo DEPOIS de a OS ter voltado — com só a voz do fisco no ar (a 3ª conferência do `live()`): o detalhe não volta, a voz não vaza, o fim do lote recarrega a lista LIVRE', () async {
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_aId)).thenAnswer((_) => refresh.future);
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_bId)).thenAnswer((_) => transmit.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                           // "Consultar"
      await pumpEventQueue();
      final voice = parkNextVoice(_aId);
      refresh.complete(const Right(ServiceOrderFiscalRefreshResult()));                   // termina → releitura (GET volta já; a voz fica)
      await pumpEventQueue(times: 20);
      expect(voice.isCompleted, isFalse);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_bId]));                   // o lote confirmado por cima (D-F177)
      await pumpEventQueue(times: 20);
      final at = states.length;
      voice.complete(const Right(_bVoice));                                                // a voz chega (a de OUTRA OS, de propósito)
      await pumpEventQueue(times: 20);
      expect(states.sublist(at).whereType<ServiceOrderDetailState>(), isEmpty, reason: 'a releitura morreu com o lote');
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _bId, attempt: 1, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final end = _shown(states);
      expect([end.runtimeType, end is ServiceOrderListState && !end.loading], [ServiceOrderListState, true]);
      expect(states.whereType<ServiceOrderDetailState>().every((s) => s.fiscal != _bVoice), isTrue, reason: 'a voz de B nunca no detalhe de A');
    });

    test('[RESISTIU] D-F193 × D-F174: o ato termina com a MESMA OS a caminho (o operador a reabriu) → a releitura vira o pedido "a caminho" (o da reabertura perde a vez); o lote confirmado DEPOIS não a derruba (a escolha do operador vence); o fim do lote só mostra o relatório; a leitura velha da reabertura que chega por último não muda nada', () async {
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_aId)).thenAnswer((_) => refresh.future);
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_bId)).thenAnswer((_) => transmit.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      final reopen = parkNextGet(_aId);
      final reread = parkNextGet(_aId);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // A a caminho (a 1ª leitura parada)
      await pumpEventQueue(times: 20);
      refresh.complete(const Right(ServiceOrderFiscalRefreshResult()));                   // o ato termina com A a caminho
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderActionSuccess>().last.orderNumber, isNull, reason: 'a OS a caminho é a tela dele');
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_bId]));                   // o lote confirmado com A a caminho
      await pumpEventQueue(times: 20);
      reread.complete(const Right(_a));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _aId, reason: 'D-F174: a OS a caminho vence o lote');
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _bId, attempt: 1, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      final at = states.length;
      reopen.complete(const Right(_a));                                                    // a leitura da reabertura, perdida, chega por último
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([states.whereType<ServiceOrderFiscalBatchDone>().length, (_shown(states) as ServiceOrderDetailState).order.id, states.sublist(at)],
          [1, _aId, isEmpty]);
    });

    test('[RESISTIU] dois atos na MESMA OS (o 2º na OS reaberta — D-F191 (b)) com as releituras FORA DE ORDEM: vale a do último ato; quando a última FALHA e a anterior chega OK depois, a tela fica na lista com UMA falha — a anterior não ressuscita o detalhe', () async {
      for (final lastFails in [false, true]) {
        final refreshes = <Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>>[];
        when(() => nfse.refresh(_aId)).thenAnswer((_) {
          final c = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
          refreshes.add(c);
          return c.future;
        });
        getQueue.clear();
        final (bloc, states, sub) = await start();
        bloc.add(const ServiceOrderViewRequested(_aId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                         // ato 1
        await pumpEventQueue();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));              // página recriada
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderViewRequested(_aId));                                 // A reaberta (chega já — sem saving: D-F191 (b))
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                         // ato 2 na A reaberta
        await pumpEventQueue();
        final g1 = parkNextGet(_aId);
        refreshes[0].complete(const Right(ServiceOrderFiscalRefreshResult()));            // ato 1 termina → releitura R1
        await pumpEventQueue(times: 20);
        final g2 = parkNextGet(_aId);
        refreshes[1].complete(const Right(ServiceOrderFiscalRefreshResult()));            // ato 2 termina → releitura R2
        await pumpEventQueue(times: 20);
        g2.complete(lastFails ? const Left(Failure(message: 'fora', statusCode: 503)) : const Right(_a));
        await pumpEventQueue(times: 20);
        final at = states.length;
        g1.complete(const Right(_a));                                                      // a releitura ANTERIOR chega por último
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        expect(states.sublist(at), isEmpty, reason: 'a releitura anterior morreu (lastFails=$lastFails)');
        final end = _shown(states);
        if (lastFails) {
          expect([end.runtimeType, (end as ServiceOrderListState).loading, states.whereType<ServiceOrderActionFailure>().length],
              [ServiceOrderListState, false, 1]);
        } else {
          expect([end.runtimeType, (end as ServiceOrderDetailState).saving], [ServiceOrderDetailState, false]);
        }
      }
    });

    test('[RESISTIU] o contador da D-F193 nunca derruba um pedido do operador: a releitura da A (em voo) morre com a página recriada; o operador abre a B; a releitura velha da A que chega depois não toca a B; e um ato da A que termina com a B aberta sai com "OS 77:" sem reler nada', () async {
      final refreshes = <Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>>[];
      when(() => nfse.refresh(_aId)).thenAnswer((_) {
        final c = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
        refreshes.add(c);
        return c.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                           // ato 1
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // A reaberta
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                           // ato 2 na A reaberta
      await pumpEventQueue();
      final staleA = parkNextGet(_aId);
      refreshes[0].complete(const Right(ServiceOrderFiscalRefreshResult()));              // ato 1 termina → releitura da A no ar
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // página recriada de novo
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));                                   // o operador abre a B
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _bId);
      final at = states.length;
      staleA.complete(const Right(_a));
      await pumpEventQueue(times: 20);
      expect(states.sublist(at), isEmpty, reason: 'a releitura velha da A não toca a B');
      final readsA = getCalls[_aId];
      refreshes[1].complete(const Right(ServiceOrderFiscalRefreshResult()));              // ato 2 da A termina com a B aberta
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final outcome = states.sublist(at).whereType<ServiceOrderActionSuccess>().single;
      expect([outcome.orderNumber, getCalls[_aId], (_shown(states) as ServiceOrderDetailState).order.id], [_numberOf[_aId], readsA, _bId]);
    });
  });

  // ---------------------------------------------------------------------
  // 2b. R14-ADV-02 — o one-shot IGUAL ao estado atual do bloc é engolido (Equatable) — achado pelo oráculo estrito do fuzz
  // ---------------------------------------------------------------------
  group('R14-ADV-02 — dois one-shots IGUAIS seguidos viram UM (o `emit` do bloc descarta o estado igual ao atual)', () {
    test('[FATO R14-ADV-02] dois "Consultar" da OS A (o 2º na A reaberta — D-F191 (b)) terminam com o operador na LISTA: os dois desfechos são o MESMO estado (`fiscalRefreshUnchanged`, "OS 77:") e o 2º é ENGOLIDO pelo bloc — sai UM aviso. Hoje sem perda de informação (o texto é idêntico); fica como conhecimento negativo: nenhuma regra pode contar one-shots iguais seguidos (e o fuzz do gate aceita a lista sem desfecho no passo quando o estado de partida já era a mesma falha — 5 vezes nas 300 sementes, todas com a MESMA `NetworkFailure` const do mock; no app real a da rede leva o `detail` da URL e difere)', () async {
      final refreshes = <Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>>[];
      when(() => nfse.refresh(_aId)).thenAnswer((_) {
        final c = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
        refreshes.add(c);
        return c.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                           // "Consultar" 1
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // A reaberta
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                           // "Consultar" 2
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // o operador volta à lista
      await pumpEventQueue(times: 20);
      refreshes[0].complete(const Right(ServiceOrderFiscalRefreshResult()));
      await pumpEventQueue(times: 20);
      refreshes[1].complete(const Right(ServiceOrderFiscalRefreshResult()));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final outcomes = states.whereType<ServiceOrderActionSuccess>().where((s) => s.messageKey == 'forms.serviceOrder.fiscalRefreshUnchanged');
      expect([outcomes.length, outcomes.single.orderNumber], [1, _numberOf[_aId]], reason: 'dois atos, UM aviso');
    });
  });

  // ---------------------------------------------------------------------
  // 3. A página — toda decisão que volta de um `await` vai pelo `_dispatch` (bloc vivo)
  // ---------------------------------------------------------------------
  group('a página — `_bloc.add` cru × `await`', () {
    test('[RESISTIU] nenhuma função da página chama `_bloc.add(` DEPOIS de um `await` (a decisão de um diálogo vai pelo `_dispatch`, que confere o bloc vivo — D-F184/R13-SOC-03); os `_bloc.add` crus que sobram são callbacks síncronos de widget (aba, filtro, paginação, toque na linha, "Transmitir pendentes")', () {
      final page = File('lib/app/modules/service_orders/presentation/page/service_order_page.dart').readAsStringSync();
      final lines = page.split('\n');
      final header = RegExp(r'^\s*(Future<[^>]*>|void|Widget|String|bool)\s+[_a-zA-Z]\w*\s*\(');
      final raw = <String>[];
      for (final m in RegExp(r'_bloc\s*\.add\(').allMatches(page)) {
        final i = '\n'.allMatches(page.substring(0, m.start)).length;   // a linha do `_bloc`
        var j = i;
        while (j > 0 && !header.hasMatch(lines[j])) {
          j--;
        }
        raw.add('${i + 1}: ${lines[i].trim()}  [função da linha ${j + 1}]');
        final body = lines.sublist(j, i + 1).join('\n');
        if (lines[i].contains('if (!_bloc.isClosed) _bloc.add(event);')) continue;   // o próprio `_dispatch`
        expect(body.contains('await '), isFalse, reason: '`_bloc.add` cru depois de um await na linha ${i + 1}: ${lines[i].trim()}');
      }
      // ignore: avoid_print
      print('`_bloc.add` crus da página:\n${raw.join('\n')}');
      expect(raw.length, greaterThan(3));
      // o `_dispatch` confere o bloc vivo; a cadeia de dois diálogos também (R13-SOC-03)
      expect(page, contains('if (!_bloc.isClosed) _bloc.add(event);'));
      expect(page, contains('if (decision != SetesDecision.yes || _bloc.isClosed || !root.mounted) return;'));
    });
  });

  // ---------------------------------------------------------------------
  // 4. Fuzz com o oráculo de TELA ESTRITO (o modelo do que o operador pediu por último)
  // ---------------------------------------------------------------------
  group('fuzz do bloc R14 — 300 sementes, oráculo de tela estrito', () {
    test('[RESISTIU] em 300 sequências aleatórias (o molde do fuzz R13: ver/abrir/voltar/aba, página recriada a qualquer momento — também com um diálogo MODAL aberto; item, faturar, cancelar OS, abrir OS, rotina mensal, lote de faturamento, pendentes → lote fiscal; transmitir, consultar, XML, DANFSe, plano/cancelar, manter; respostas em ordem aleatória, ~25 % falhas) com um MODELO do último pedido de tela do operador (lista / lote confirmado sobre o detalhe / ver X a caminho / abrir OS a caminho / detalhe X chegou): (1) NENHUM detalhe sai fora do modelo — nunca o de outra OS, nunca depois de uma lista pedida, nunca por cima do lote que tirou o detalhe ABERTO (D-F193); (2) nenhuma lista derruba o detalhe aberto/a caminho sem um desfecho no mesmo passo; (3) o plano do 1º passo do cancelamento abre o diálogo SE E SÓ SE o modelo é a OS dele (aberta ou a caminho — D-F194; fora dela nada, nem one-shot); (4) todo desfecho sai sem número exatamente quando o modelo é a OS dele, com o NÚMERO dela senão; (5) no repouso a tela É o último pedido (nunca "a caminho" perdido), sem spinner/saving, com a voz da SUA OS. Impressos (sem assert): o R14-ADV-01 (ato nascido com a OS a caminho, ela chega sem saving), o D-F191 (b) e o R14-ADV-02 (o desfecho IGUAL ao estado atual, engolido pelo bloc — a única tolerância do oráculo (2))', () async {
      const voiceOf = {_aId: _aVoice, _bId: _bVoice};
      const effectOf = {_aId: _aEffect, _bId: _bEffect};
      const orderOf = {_newId: _newOrder, _aId: _a, _bId: _b};
      final cover = <String, int>{};
      void count(String k) => cover[k] = (cover[k] ?? 0) + 1;
      for (var seed = 1; seed <= 300; seed++) {
        final rnd = Random(seed * 104729);
        final flights = <_Flight>[];
        final trace = <String>[];
        // o MODELO do último pedido de tela do operador
        var last = 'list'; // list | longOp | view | open | detail
        int? os;
        var openSeq = 0;
        // o passo corrente (o listener confere cada emissão contra ele)
        var stepKind = 'add';
        ServiceOrderEvent? stepEvent;
        _Flight? stepFlight;
        var stepHadOutcome = false;
        ServiceOrderState? stepStartState;   // o estado do bloc no começo do passo (o `emit` IGUAL ao atual é engolido — Equatable)
        var stepEmits = 0;                   // R15-SOC-04 (i): as emissões do passo corrente (a tolerância do desfecho engolido exige a 1ª)
        var stepPlanShown = false;
        final violations = <String>[];
        String why() => 'seed $seed\n${trace.join('\n')}';
        String tagNow() {
          final e = stepEvent;
          final f = stepFlight;
          if (stepKind == 'add' && e is ServiceOrderCancelFlowRequested) return 'flow';
          if (stepKind == 'add' && e is ServiceOrderOpenRequested) return 'open$openSeq';
          final bornOnTheWay = stepKind == 'add' && last == 'view' && e != null && e.props.isNotEmpty && e.props.first == os;
          if (bornOnTheWay) return 'onTheWay';
          if (stepKind == 'complete' && f != null && f.tag == 'onTheWay') return 'onTheWay';
          return '';
        }

        Failure fail() => rnd.nextBool() ? const Failure(message: 'x', statusCode: 500) : const NetworkFailure();
        Future<Either<Failure, T>> park<T>(String label, T Function() ok) {
          final c = Completer<Either<Failure, T>>();
          flights.add(_Flight(label, (good) => c.complete(good ? Right(ok()) : Left(fail())), tagNow()));
          return c.future;
        }

        repo = ServiceOrderRepoMock();
        nfse = NfseRepoMock();
        invoice = InvoiceRepoMock();
        when(() => repo.getList(any(), any(),
                page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
            .thenAnswer((_) => park('list', () => _page([_newId, _aId, _bId])));
        for (final id in orderOf.keys) {
          when(() => repo.getById(id)).thenAnswer((_) => park('get $id', () => orderOf[id]!));
        }
        const authorizedPlanBlocks = [
          CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
        ];
        for (final id in voiceOf.keys) {
          when(() => nfse.getView(id)).thenAnswer((_) => park('voice $id', () => voiceOf[id]!));
          when(() => invoice.fiscalEffect(id)).thenAnswer((_) => park('effect $id', () => effectOf[id]!));
          when(() => nfse.refresh(id)).thenAnswer((_) => park('refresh $id', () => const ServiceOrderFiscalRefreshResult()));
          when(() => nfse.xml(id)).thenAnswer((_) => park('xml $id', () => '<x/>'));
          when(() => nfse.danfse(id)).thenAnswer((_) => park('danfse $id', () => 'JVBE'));
          when(() => invoice.cancelPlan(id)).thenAnswer((_) => park('plan $id',
              () => rnd.nextBool() ? ServiceOrderCancelPlan(orderId: id, cancellable: true) : ServiceOrderCancelPlan(orderId: id, blocks: authorizedPlanBlocks)));
          when(() => nfse.cancel(id, any())).thenAnswer((_) => park('nfsecancel $id', () => ServiceOrderFiscalCancelResult(invoiceId: id, warnings: const ['aviso'])));
          when(() => invoice.cancel(id, any())).thenAnswer((_) => park('localcancel $id', () => ServiceOrderInvoiceCancelResult(orderId: id, invoiceNumber: '9')));
          when(() => invoice.cancelWaiver(id, any())).thenAnswer((_) => park('waiver $id', () => ServiceOrderCancelWaiverResult(orderId: id)));
        }
        when(() => nfse.transmit(any())).thenAnswer((inv) {
          final id = inv.positionalArguments[0] as int;
          return park('transmit $id', () => ServiceOrderTransmitResult(invoiceId: id, attempt: 1, accessKey: 'K'));
        });
        when(() => repo.open(5)).thenAnswer((_) => park('post', () => _newId));
        when(() => repo.itemPost(_newId, any())).thenAnswer((_) => park('item $_newId', () => 1));
        when(() => repo.invoice(_newId, any())).thenAnswer((_) => park('invoice $_newId', () => const ServiceOrderInvoiceResult(invoiceNumber: '1')));
        when(() => repo.cancel(_newId)).thenAnswer((_) => park('cancelOs $_newId', () => unit));
        when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
        when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => park('batch', () => BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: _newId, ok: true)])));
        when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => park('pending',
            () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: _aNote)], page: 1, pageSize: 100, total: 1)));

        const actKinds = {'transmit', 'refresh', 'xml', 'danfse', 'plan', 'nfsecancel', 'localcancel', 'waiver', 'item', 'invoice', 'cancelOs'};
        const longOps = {ServiceOrderFiscalTransmitBatchRequested, ServiceOrderBatchInvoiceRequested, ServiceOrderMonthlyRunRequested,
            ServiceOrderFiscalPendingRequested};
        final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
        final states = <ServiceOrderState>[];
        bool onWay() => last == 'view' || last == 'open';
        final sub = bloc.stream.listen((s) {
          states.add(s);
          stepEmits++;
          final (isOutcome, about) = _outcome(s);
          if (isOutcome) {
            stepHadOutcome = true;
            final f = stepFlight;
            if (stepKind == 'complete' && f != null && actKinds.contains(f.kind)) {
              final own = (last == 'view' || last == 'detail' || last == 'open') && os == f.os;
              count(own ? 'outcomeOnOwn' : 'outcomeElsewhere');
              if (about != (own ? null : _numberOf[f.os])) {
                violations.add('(4) desfecho de ${f.label} com about=$about (modelo $last $os) — ${why()}');
              }
            }
          }
          if (s is ServiceOrderCancelPlanReady) stepPlanShown = true;
          if (s is ServiceOrderDetailState) {
            final id = s.order.id;
            if (!((last == 'view' || last == 'open' || last == 'detail') && os == id)) {
              if (last == 'longOp') count('resurrectedOverLongOp');
              violations.add('(1) detalhe $id emitido com o modelo em $last $os — ${why()}');
            } else if (onWay()) {
              // a OS pedida CHEGOU — com um ato dela em voo? (nascido com ela a caminho = R14-ADV-01; antes = D-F191 (b))
              final inFlight = flights.where((x) => actKinds.contains(x.kind) && x.os == id).toList();
              if (!s.saving && inFlight.isNotEmpty) {
                count(inFlight.any((x) => x.tag == 'onTheWay') ? 'R14-ADV-01 landedWithoutSaving' : 'D-F191b landedWithoutSaving');
              }
              last = 'detail';
            }
          } else if (s is ServiceOrderListState) {
            if (stepKind == 'complete') {
              if (onWay() || last == 'detail') {
                if (!stepHadOutcome && stepStartState is ServiceOrderActionFailure && stepEmits == 1) {
                  // R14-ADV-02: o desfecho do passo era IGUAL ao estado atual (a mesma falha, o mesmo número) e o bloc o engoliu — R15-SOC-04 (i):
                  // só quando a lista é a 1ª emissão do passo (o desfecho engolido vem ANTES dela); um passo que emitiu outra coisa antes da
                  // lista sem desfecho é violação, parta de onde partir
                  count('R14-ADV-02 outcomeSwallowed');
                } else if (!stepHadOutcome) {
                  violations.add('(2) lista emitida com o modelo em $last $os, sem desfecho no passo — ${why()}');
                }
                last = 'list';
                os = null;
              }
            } else if (stepEvent != null && longOps.contains(stepEvent.runtimeType) && last == 'detail') {
              last = 'longOp';   // o lote confirmado POR CIMA do detalhe aberto (D-F177) — a tela é dele
              os = null;
            }
          }
        });
        _Dialog? dialog;
        var pendingSeen = 0;
        var planSeen = 0;
        Future<void> add(ServiceOrderEvent e) async {
          trace.add('${e.runtimeType}${e.props}');
          if (e is ServiceOrderListRequested || e is ServiceOrderBackToListPressed) {
            last = 'list';
            os = null;
          } else if (e is ServiceOrderViewRequested) {
            last = 'view';
            os = e.id;
          } else if (e is ServiceOrderOpenRequested) {
            last = 'open';
            os = null;   // o id só com o POST (D-F191)
            openSeq++;
          }
          stepKind = 'add';
          stepEvent = e;
          stepFlight = null;
          stepHadOutcome = false;
          stepEmits = 0;
          stepPlanShown = false;
          stepStartState = states.lastOrNull;
          if (!bloc.isClosed) bloc.add(e);                                              // o `_dispatch` da página (D-F184)
          await pumpEventQueue();
        }

        Future<void> completeOne({double okRate = 0.75}) async {
          var i = rnd.nextInt(flights.length);
          for (var retry = 0; retry < 2 && actKinds.contains(flights[i].kind) && flights.length > 1; retry++) {
            i = rnd.nextInt(flights.length);
          }
          // a porta da D-F194: com a OS a caminho e o plano DELA no ar, metade das vezes o plano chega antes dela
          final planOfTheWay = flights.indexWhere((x) => x.kind == 'plan' && x.tag == 'flow' && last == 'view' && x.os == os);
          if (planOfTheWay >= 0 && rnd.nextBool()) i = planOfTheWay;
          final f = flights.removeAt(i);
          final ok = rnd.nextDouble() < okRate;
          // (3) o 1º passo do cancelamento: o diálogo SE E SÓ SE o modelo é a OS dele (aberta ou a caminho)
          final planOwn = (last == 'view' || last == 'detail') && os == f.os;
          if (f.kind == 'post' && ok && last == 'open' && f.tag == 'open$openSeq') os = _newId;   // a OS a caminho ganha o id
          final at = states.length;
          trace.add('<- ${f.label}${f.tag.isEmpty ? '' : ' [${f.tag}]'} ${ok ? 'ok' : 'FAIL'}');
          stepKind = 'complete';
          stepEvent = null;
          stepFlight = f;
          stepHadOutcome = false;
          stepEmits = 0;
          stepPlanShown = false;
          stepStartState = states.lastOrNull;
          f.finish(ok);
          await pumpEventQueue();
          if (f.kind == 'plan' && f.tag == 'flow' && ok) {
            count(planOwn ? 'planOnOwn' : 'planElsewhere');
            if (stepPlanShown != planOwn) violations.add('(3) plano de ${f.os}: diálogo=$stepPlanShown, modelo $last $os — ${why()}');
            if (!planOwn && states.sublist(at).any((s) => _outcome(s).$1)) {
              violations.add('(3) plano fora da OS dele virou one-shot — ${why()}');
            }
          }
          for (final s in states.sublist(at)) {
            if (s is ServiceOrderBatchInvoiceDone) {
              for (final e in s.report.results) {
                if (s.numbers[e.orderId] != _numberOf[e.orderId]) violations.add('relatório do lote com o número errado — ${why()}');
              }
              count('batchReport');
            }
            if (s is ServiceOrderFiscalBatchDone) {
              if (s.noteNumbers[_aId] != _aNote) violations.add('lote fiscal sem o nº da nota — ${why()}');
              count('fiscalReport');
            }
          }
        }

        await add(const ServiceOrderListRequested(status: 'A', filter: ''));            // o initState
        for (var step = 0; step < 120; step++) {
          if (flights.isNotEmpty && rnd.nextDouble() < 0.5) {
            await completeOne();
            continue;
          }
          final pick = rnd.nextInt(100);
          final shown = _shownOrNull(states);
          final d = dialog;
          if (d != null) {
            if (pick < 15) {
              count('recreatedUnderDialog');
              await add(const ServiceOrderListRequested(status: 'A', filter: ''));
            } else if (pick < 85) {
              dialog = null;
              if (d.decision is ServiceOrderCancelConfirmed && onWay()) count('decisionWithOsOnTheWay');
              await add(d.decision);
            } else if (pick < 95) {
              dialog = null;
            }
            continue;
          }
          final plans = states.whereType<ServiceOrderCancelPlanReady>().toList();
          if (plans.length > planSeen) {
            planSeen = plans.length;
            final plan = plans.last.plan;
            if (onWay()) count('planDialogOverOnTheWay');
            dialog = _Dialog(ServiceOrderCancelConfirmed(orderId: plan.orderId, reason: 'motivo', atAuthority: plan.onlyAuthorityStands));
            continue;
          }
          final loaded = states.whereType<ServiceOrderFiscalPendingLoaded>().length;
          if (loaded > pendingSeen) {
            pendingSeen = loaded;
            dialog = _Dialog(const ServiceOrderFiscalTransmitBatchRequested([_aId]));
            continue;
          }
          final recreate = shown is ServiceOrderDetailState && shown.saving ? pick < 35 : pick < 6;
          if (recreate) {
            await add(const ServiceOrderListRequested(status: 'A', filter: ''));
          } else if (shown is ServiceOrderDetailState) {
            if (shown.saving) {
              // botões travados — esperar
            } else if (pick < 15) {
              await add(const ServiceOrderBackToListPressed());
            } else if (shown.order.isOpen) {
              final r = rnd.nextInt(3);
              dialog = _Dialog(r == 0
                  ? const ServiceOrderItemSaveRequested(orderId: _newId, input: _item)
                  : r == 1
                      ? const ServiceOrderInvoiceRequested(orderId: _newId, input: _input)
                      : const ServiceOrderCancelRequested(_newId));
            } else {
              final id = shown.order.id;
              final r = rnd.nextInt(7);
              if (r == 0) {
                dialog = _Dialog(ServiceOrderFiscalCancelWaiverRequested(orderId: id, reason: 'manter'));
              } else {
                await add([
                  ServiceOrderTransmitRequested(id),
                  ServiceOrderCancelFlowRequested(id),
                  ServiceOrderFiscalRefreshRequested(id),
                  ServiceOrderFiscalXmlRequested(id),
                  ServiceOrderFiscalDanfseRequested(id),
                  ServiceOrderCancelFlowRequested(id),
                ][r - 1]);
              }
            }
          } else if (shown is ServiceOrderListState) {
            if (shown.loading) {
              if (onWay() && pick < 85) {
                // esperar a OS pedida
              } else if (pick < 35) {
                await add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
              } else if (pick < 45) {
                dialog = _Dialog(const ServiceOrderOpenRequested(5));                     // o FAB (lookup de cliente) — nunca travado
              }
            } else if (pick < 60) {
              // reabrir a OS de um ato no ar (D-F191 (b)) — e, com o plano do cancelamento no ar, quase sempre a OS dele (a porta da D-F194)
              final planInAir = flights.where((f) => f.kind == 'plan' && f.tag == 'flow').map((f) => f.os!).toList();
              final inAir = planInAir.isNotEmpty && rnd.nextInt(4) > 0
                  ? planInAir
                  : flights.where((f) => actKinds.contains(f.kind) && (f.os == _aId || f.os == _bId)).map((f) => f.os!).toList();
              await add(ServiceOrderViewRequested(inAir.isNotEmpty && rnd.nextInt(3) > 0
                  ? inAir[rnd.nextInt(inAir.length)]
                  : [_aId, _bId, _aId, _bId, _newId][rnd.nextInt(5)]));
            } else if (pick < 64) {
              dialog = _Dialog(const ServiceOrderOpenRequested(5));
            } else if (pick < 72) {
              await add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
            } else if (pick < 77) {
              dialog = _Dialog(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
            } else if (pick < 85) {
              await add(const ServiceOrderFiscalPendingRequested());
            } else if (pick < 90 && shown.items.any((i) => i.id == _newId)) {
              dialog = _Dialog(const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input));
            }
          }
        }

        dialog = null;
        for (var guard = 0; flights.isNotEmpty; guard++) {
          expect(guard, lessThan(3000), reason: 'seed $seed não drena');
          await completeOne(okRate: 0.85);
        }
        await pumpEventQueue(times: 20);
        // (5) o repouso É o último pedido
        final rest = _shown(states);
        if (onWay()) {
          violations.add('(5) o pedido do operador ($last $os) se perdeu: nada chegou — ${why()}');
        } else if (last == 'detail') {
          if (rest is! ServiceOrderDetailState || rest.order.id != os || rest.saving) {
            violations.add('(5) repouso ${rest.runtimeType} ≠ o detalhe $os pedido (ou saving preso) — ${why()}');
          }
        } else if (rest is! ServiceOrderListState || rest.loading) {
          violations.add('(5) repouso ${rest.runtimeType} ≠ a lista livre pedida ($last) — ${why()}');
        }
        for (final s in states.whereType<ServiceOrderDetailState>()) {
          final id = s.order.id;
          if (!((s.fiscal == null || s.fiscal == voiceOf[id]) && (s.effect == null || s.effect == effectOf[id]))) {
            violations.add('detalhe $id emitido com a voz/efeito de OUTRA OS — ${why()}');
          }
        }
        await sub.cancel();
        await bloc.close();
        expect(violations, isEmpty, reason: violations.isEmpty ? '' : violations.first);
      }
      // ignore: avoid_print
      print('cobertura do fuzz R14: $cover');
      const minimum = {'outcomeOnOwn': 300, 'outcomeElsewhere': 100, 'recreatedUnderDialog': 100, 'batchReport': 5, 'fiscalReport': 5,
          'planOnOwn': 20, 'planElsewhere': 5, 'planDialogOverOnTheWay': 10, 'decisionWithOsOnTheWay': 3};
      for (final e in minimum.entries) {
        expect(cover[e.key] ?? 0, greaterThan(e.value), reason: 'o fuzz quase não exercitou "${e.key}": $cover');
      }
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}
