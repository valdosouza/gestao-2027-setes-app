// GATE ADVERSARIAL independente do DELTA da Rodada 13 da F2a/F2b (setes-app) — alvo: `495267b..9a5d2a8` (branch f2b):
// D-F187 (o NÚMERO que a tela mostra — `_shownNumbers`; `orderNumber` nos one-shots; `numbers` no relatório do lote de faturamento; o nº
// da NOTA no lote fiscal), D-F189 (o 2º diálogo da cadeia pelo Navigator RAIZ; o plano da MESMA OS reaberta; a pesquisa avançada por
// `_dispatch`; XML/DANFSe de outra OS com "OS N:"), D-F191 (a marca "a caminho" carrega a OS — `_pendingDetailOrder`/`_showsOrder`;
// `_rereadAfterAct` = PEDIDO NOVO de detalhe da OS).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R13-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_r13_gate_test.dart
//   - `[FATO R13-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada ACHADO.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail (molde dos gates R9–R12).
// O lado setes-api deste gate: `setes-api-f2a/src/__tests__/adversarial-f2a-r13-gate.test.ts`.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:flutter/material.dart';
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

/// Os NÚMEROS que a tela mostra PERMUTAM os ids (o número de cada OS é o id de OUTRA) — qualquer troca id × número no desfecho, nos
/// relatórios ou no "OS N:" aparece como a OS ERRADA (a forma do dev: 344 de 344 OS com número ≠ id — gate R12, R12-ADV-06).
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

/// O nº da NOTA que a pendente traz (D-F187 — o lote fiscal se identifica por ele).
const _aNote = '9001';

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

PagedResult<ServiceOrderListItem> _page(List<int> ids) => PagedResult(items: [
      for (final id in ids) ServiceOrderListItem(id: id, number: _numberOf[id], customerId: 1, status: id == _newId ? 'A' : 'F'),
    ], page: 1, pageSize: 10, total: ids.length);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState? _shownOrNull(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
ServiceOrderState _shown(List<ServiceOrderState> states) => _shownOrNull(states)!;

/// O one-shot de DESFECHO de um ato (os seis que levam a identidade da OS — D-F182/D-F189) — (é desfecho?, o número que leva).
(bool, int?) _outcome(ServiceOrderState s) => switch (s) {
      ServiceOrderActionSuccess(:final orderNumber) => (true, orderNumber),
      ServiceOrderActionFailure(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalNotice(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalWarnings(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalXmlReady(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalDanfseReady(:final orderNumber) => (true, orderNumber),
      _ => (false, null),
    };

/// Uma resposta EM VOO do fuzzer: a chamada fica parada até o agendador decidir (ok / falha).
class _Flight {
  _Flight(this.label, this.finish);
  final String label;
  final void Function(bool ok) finish;
  int? get os => int.tryParse(label.split(' ').last);
  String get kind => label.split(' ').first;
}

/// Um diálogo MODAL aberto no Navigator raiz (sobrevive à página recriada — D-F184/D-F189): a decisão que ele despacha ao confirmar.
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

  /// Cada leitura de uma OS pega o PRÓXIMO futuro da fila dela (ou a resposta imediata de sempre).
  late Map<int, List<Completer<Either<Failure, ServiceOrderFull>>>> getQueue;
  late Map<int, int> getCalls;

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    getQueue = {};
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
    when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) async => const Right(_aEffect));
    when(() => invoice.fiscalEffect(_bId)).thenAnswer((_) async => const Right(_bEffect));
    when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoice));
    when(() => nfse.getView(_bId)).thenAnswer((_) async => const Right(_bVoice));
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

  // ---------------------------------------------------------------------
  // 1. R13-ADV-01 — a releitura da D-F191 (PEDIDO NOVO, sem a guarda `act:`) ressuscita o detalhe por cima do lote confirmado depois
  // ---------------------------------------------------------------------
  group('R13-ADV-01 — `_rereadAfterAct` × o lote fiscal confirmado por cima do detalhe', () {
    /// "Transmitir pendentes" na aba Faturadas (a fotografia demora — todas as páginas); o FAB (nunca travado) abre a OS NOVA no meio; o
    /// operador lança um item nela; a fotografia chega e a confirmação abre POR CIMA do detalhe (D-F177); o item termina e a D-F191 pede o
    /// detalhe de novo; o operador CONFIRMA o lote — a tela vira a lista em loading (D-F169, `supersede: false`) — e a releitura chega.
    Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>, Completer<Either<Failure, ServiceOrderTransmitResult>>)>
        rereadInFlightThenLoteConfirmed() async {
      final pending = Completer<Either<Failure, PagedResult<ServiceOrderFiscalPending>>>();
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => pending.future);
      final item = Completer<Either<Failure, int>>();
      when(() => repo.itemPost(_newId, any())).thenAnswer((_) => item.future);
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmit.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalPendingRequested());                              // a fotografia (todas as páginas) no ar
      await pumpEventQueue();
      bloc.add(const ServiceOrderOpenRequested(5));                                      // o FAB — nunca travado
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
      bloc.add(const ServiceOrderItemSaveRequested(orderId: _newId, input: _item));      // um item na OS nova
      await pumpEventQueue();
      pending.complete(const Right(PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: _aNote)], page: 1, pageSize: 100, total: 1)));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderFiscalPendingLoaded>(), hasLength(1));        // a confirmação abre por cima do detalhe (D-F177)
      final reread = parkNextGet(_newId);
      item.complete(const Right(1));                                                      // o item termina → a D-F191 pede o detalhe DE NOVO
      await pumpEventQueue(times: 20);
      expect(reread.isCompleted, isFalse);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_aId]));                  // o operador CONFIRMA o lote
      await pumpEventQueue(times: 20);
      expect([_shown(states).runtimeType, (_shown(states) as ServiceOrderListState).loading], [ServiceOrderListState, true],
          reason: 'o lote trocou a tela pela lista em loading (D-F169)');
      reread.complete(const Right(_newOrder));                                            // a releitura automática chega
      await pumpEventQueue(times: 20);
      return (bloc, states, sub, transmit);
    }

    test('[CORRIGIDO D-F193 (= Q-F196-SOC-02 (a)) — era o FATO R13-ADV-01: a releitura da OS ABERTA é a de um ATO (`act: true`) e morre com o lote confirmado por cima] com o lote fiscal confirmado DEPOIS de a releitura do fim do item começar, a releitura (agora um PEDIDO NOVO — `_reloadDetail(generation:)` sem o `act: true` da R12, que conferia `_stillOnDetail` = detalhe ainda aberto) EMITE o detalhe da OS nova POR CIMA do lote em andamento: a tela que o operador acabou de escolher (o lote — a lista em loading) é trocada por uma recarga AUTOMÁTICA. A marca "a caminho" da releitura faz o fim do lote achar "OS aberta" e só mostrar o relatório', () async {
      final (bloc, states, sub, transmit) = await rereadInFlightThenLoteConfirmed();
      final shown = _shown(states);
      expect([shown.runtimeType, (shown as ServiceOrderListState).loading, transmit.isCompleted], [ServiceOrderListState, true, false],
          reason: 'a tela do lote (lista em loading) fica — o detalhe NÃO volta por cima');
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final done = states.whereType<ServiceOrderFiscalBatchDone>().single;
      final end = _shown(states);
      expect([done.noteNumbers[_aId], end.runtimeType, end is ServiceOrderListState && !end.loading], [_aNote, ServiceOrderListState, true],
          reason: 'D-F187: o relatório pelo nº da nota; o fim do lote recarrega a lista LIVRE');
    });

    test('[CORRIGIDO R13-ADV-01 LOW — D-F193] a recarga AUTOMÁTICA do fim de um ato (D-F191) não volta por cima de um lote que o operador confirmou DEPOIS de ela começar — a regra do R10-SOC-03 ("um lote confirmado por cima dele troca a tela pela lista sem subir o contador — D-F174. Senão, só o one-shot do desfecho; a tela de agora fica"), que a R12 cumpria com o `act: true` da releitura. Correção sugerida: a releitura pedir o detalhe de novo SÓ enquanto ele não saiu (`live()` = contador E `_detail != null || a caminho do OPERADOR`), ou o `_showListLoading(supersede: false)` matar a marca "a caminho" das releituras (não a do operador)', () async {
      final (bloc, states, sub, transmit) = await rereadInFlightThenLoteConfirmed();
      final shown = _shown(states);
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(shown, isA<ServiceOrderListState>(), reason: 'a tela do lote (lista em loading) fica até o fim dele');
    });

    test('[RESISTIU] o detalhe que o OPERADOR pediu (FAB) e ainda está A CAMINHO quando o lote é confirmado VENCE (D-F174) — o caso de design que a R13-ADV-01 imita, sem releitura nenhuma', () async {
      final pending = Completer<Either<Failure, PagedResult<ServiceOrderFiscalPending>>>();
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => pending.future);
      when(() => nfse.transmit(_aId)).thenAnswer((_) async => const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1, accessKey: 'K')));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue();
      final onTheWay = parkNextGet(_newId);
      bloc.add(const ServiceOrderOpenRequested(5));                                      // a OS nova A CAMINHO
      await pumpEventQueue(times: 20);
      pending.complete(const Right(PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: _aNote)], page: 1, pageSize: 100, total: 1)));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_aId]));
      await pumpEventQueue(times: 20);
      onTheWay.complete(const Right(_newOrder));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([(_shown(states) as ServiceOrderDetailState).order.id, states.whereType<ServiceOrderFiscalBatchDone>().single.noteNumbers],
          [_newId, {_aId: _aNote}]);
    });
  });

  // ---------------------------------------------------------------------
  // 2. R13-ADV-02 — o plano do cancelamento × a MESMA OS reaberta ainda A CAMINHO (D-F189 só cobriu a reaberta)
  // ---------------------------------------------------------------------
  group('R13-ADV-02 — o plano da MESMA OS reaberta A CAMINHO', () {
    Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>, Completer<Either<Failure, ServiceOrderFull>>)>
        planArrivesWithSameOsOnTheWay() async {
      final plan = Completer<Either<Failure, ServiceOrderCancelPlan>>();
      when(() => invoice.cancelPlan(_aId)).thenAnswer((_) => plan.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderCancelFlowRequested(_aId));                              // "Cancelar nota" — o plano demora
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada (cruzar 1100 px — D-F160)
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      final onTheWay = parkNextGet(_aId);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // reabre a MESMA OS — a caminho
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue);
      plan.complete(const Right(ServiceOrderCancelPlan(orderId: _aId, cancellable: true)));
      await pumpEventQueue(times: 20);
      return (bloc, states, sub, onTheWay);
    }

    test('[CORRIGIDO D-F194 (= Q-F196-SOC-03 (a)) — era o FATO R13-ADV-02: o plano abre também com a MESMA OS a caminho (`_showsOrder`)] o plano do "Cancelar nota" chega com a MESMA OS reaberta ainda A CAMINHO (o `_detail` é nulo; a marca "a caminho" é dela — D-F191): `_onCancelFlowRequested` confere `_stillOnDetail || _detail?.id == orderId` (o `_detail`, não o `_showsOrder` da D-F191) e DESCARTA o plano EM SILÊNCIO — nenhum diálogo, nenhum one-shot, nenhuma frase; a OS chega e o clique do operador simplesmente não aconteceu (o descarte silencioso que a D-F189 fechou para a reaberta, pela janela do "a caminho" — R10-SOC-01: "aberto" e "a caminho" são UM estado)', () async {
      final (bloc, states, sub, onTheWay) = await planArrivesWithSameOsOnTheWay();
      final at = states.length;
      onTheWay.complete(const Right(_a));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderCancelPlanReady>().single.plan.orderId, _aId, reason: 'o "Cancelar nota" do operador não some calado');
      expect((_shown(states) as ServiceOrderDetailState).order.id, _aId);
      expect(states.sublist(at).whereType<ServiceOrderCancelPlanReady>(), isEmpty, reason: 'o plano saiu UMA vez, quando chegou');
    });

    test('[CORRIGIDO R13-ADV-02 LOW — D-F194] o plano da MESMA OS reaberta abre também quando ela está A CAMINHO (D-F189 + D-F191: a OS a caminho é a tela dela) — o "Cancelar nota" do operador nunca some calado. Correção sugerida: `_onCancelFlowRequested` decidir por `_showsOrder(event.orderId)` (o mesmo predicado do `_outcomeOrder`/`_rereadAfterAct`), não pelo `_detail?.id`', () async {
      final (bloc, states, sub, onTheWay) = await planArrivesWithSameOsOnTheWay();
      onTheWay.complete(const Right(_a));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderCancelPlanReady>().single.plan.orderId, _aId);
    });
  });

  // ---------------------------------------------------------------------
  // 3. D-F191 — o que RESISTIU (sequências dirigidas)
  // ---------------------------------------------------------------------
  group('D-F191 — sequências dirigidas', () {
    test('[RESISTIU] a marca "a caminho" do FAB não carrega OS até o POST responder: um ato da OS A (de antes) que termina com o POST no ar sai COM o número da A ("OS 77") e NÃO relê a A; o POST que falha mata a marca (o ato seguinte da A também sai com o número); a OS nova chega normalmente', () async {
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_aId)).thenAnswer((_) => refresh.future);
      final post = Completer<Either<Failure, int>>();
      when(() => repo.open(5)).thenAnswer((_) => post.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderOpenRequested(5));                                      // o FAB — o id só depois do POST
      await pumpEventQueue(times: 20);
      final readsBefore = getCalls[_aId];
      refresh.complete(const Right(ServiceOrderFiscalRefreshResult()));
      await pumpEventQueue(times: 20);
      final first = states.whereType<ServiceOrderActionSuccess>().last;
      expect([first.orderNumber, getCalls[_aId]], [_numberOf[_aId], readsBefore], reason: 'o desfecho da A com o número dela; a A não é relida');
      post.complete(const Left(Failure(message: 'trava D5', statusCode: 409)));
      await pumpEventQueue(times: 20);
      // de novo, com a marca do FAB morta: a A reaberta e outro ato dela; a página recriada; o desfecho fora da A leva o número
      final xml = Completer<Either<Failure, String>>();
      when(() => nfse.xml(_aId)).thenAnswer((_) => xml.future);
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalXmlRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      xml.complete(const Right('<x/>'));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderFiscalXmlReady>().single.orderNumber, _numberOf[_aId]);
      when(() => repo.open(5)).thenAnswer((_) async => const Right(_newId));
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
    });

    test('[RESISTIU] a releitura da D-F191 não entra em laço: cada fim de ato pede a OS UMA vez — 3 atos seguidos na mesma OS = 3 leituras a mais; a releitura que FALHA volta à lista com a falha (uma vez) e não pede de novo', () async {
      when(() => nfse.refresh(_aId)).thenAnswer((_) async => const Right(ServiceOrderFiscalRefreshResult()));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      final base = getCalls[_aId]!;
      for (var i = 0; i < 3; i++) {
        bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
        await pumpEventQueue(times: 20);
      }
      expect(getCalls[_aId], base + 3);
      final failing = parkNextGet(_aId);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
      await pumpEventQueue(times: 20);
      failing.complete(const Left(Failure(message: 'fora', statusCode: 503)));
      await pumpEventQueue(times: 40);
      await sub.cancel();
      await bloc.close();
      expect([getCalls[_aId], _shown(states).runtimeType, states.whereType<ServiceOrderActionFailure>().length],
          [base + 4, ServiceOrderListState, 1]);
    });
  });

  // ---------------------------------------------------------------------
  // 3b. D-F189 — o 2º diálogo da cadeia pelo Navigator RAIZ (o mecanismo, com a página DESMONTADA no meio)
  // ---------------------------------------------------------------------
  group('D-F189 — o 2º diálogo pelo Navigator raiz', () {
    testWidgets('[RESISTIU — o mecanismo] o contexto do Navigator RAIZ capturado ANTES do 1º diálogo segue montado depois que a página que o abriu é DESMONTADA com o diálogo aberto (cruzar 1100 px — D-F160); o 2º diálogo abre por ele e devolve o motivo (o `mounted` da página daria false e a cadeia caía — o descarte da R12-SOC-06). E a página faz exatamente isso: `root` capturado antes do `askDecision`, `root.mounted` entre os dois, `showCancelInvoiceDialog(root, …)`', (tester) async {
      final show = ValueNotifier(true);
      late BuildContext pageContext;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, v, __) => v
                ? Builder(builder: (c) {
                    pageContext = c;
                    return const Text('página');
                  })
                : const Text('outra página'),
          ),
        ),
      ));
      final root = Navigator.of(pageContext, rootNavigator: true).context;
      final first = showDialog<bool>(
          context: pageContext,
          builder: (c) => AlertDialog(content: const Text('cancelar no fisco?'), actions: [
                TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('sim')),
              ]));
      await tester.pumpAndSettle();
      show.value = false;                                                                // a página recriada com o 1º diálogo aberto
      await tester.pumpAndSettle();
      expect([pageContext.mounted, find.text('cancelar no fisco?').evaluate().length], [false, 1]);
      await tester.tap(find.text('sim'));
      await tester.pumpAndSettle();
      expect([await first, root.mounted], [true, true]);
      final second = showDialog<String>(
          context: root,
          builder: (c) => AlertDialog(content: const Text('motivo'), actions: [
                TextButton(onPressed: () => Navigator.of(c).pop('motivo digitado'), child: const Text('ok')),
              ]));
      await tester.pumpAndSettle();
      expect(find.text('motivo'), findsOneWidget);
      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle();
      expect(await second, 'motivo digitado');
      final page = File('lib/app/modules/service_orders/presentation/page/service_order_page.dart').readAsStringSync();
      final chain = page.substring(page.indexOf('case FiscalBarrierKind.authorized:'), page.indexOf('case FiscalBarrierKind.reconfirm:'));
      expect(chain.indexOf('final root = Navigator.of(context, rootNavigator: true).context;'), lessThan(chain.indexOf('await askDecision(')));
      expect(chain, contains('if (decision != SetesDecision.yes || _bloc.isClosed || !root.mounted) return;'));
      expect(chain, contains('await showCancelInvoiceDialog(root, number);'));
    });
  });

  // ---------------------------------------------------------------------
  // 4. D-F187 — fuzz com os números PERMUTADOS (o número de cada OS é o id de outra)
  // ---------------------------------------------------------------------
  group('fuzz do bloc — 250 sementes com número ≠ id (D-F187 + D-F191)', () {
    test('[RESISTIU] em 250 sequências aleatórias (o molde do fuzz R12 — ver/abrir/voltar/aba, página recriada a qualquer momento, também com um diálogo MODAL aberto que despacha a decisão DEPOIS; item, faturar, cancelar OS, abrir OS, rotina mensal, lote de faturamento, pendentes → lote fiscal; transmitir, consultar, XML, DANFSe, plano/cancelar, manter; respostas em ordem aleatória, ~25 % falhas) com os NÚMEROS PERMUTANDO os ids: TODO desfecho (inclusive XML/DANFSe) sai sem número sobre a OS dele (aberta ou a caminho) e com o NÚMERO dela — nunca o id, nunca o de outra — fora dela; o relatório do lote de faturamento cita os números; o do lote fiscal, o nº da nota; no repouso nada fica em spinner/saving e o detalhe tem a voz da SUA OS. Impressos (sem assert): a R13-ADV-01 e a R13-ADV-02 achadas pelo próprio fuzz', () async {
      const voiceOf = {_aId: _aVoice, _bId: _bVoice};
      const effectOf = {_aId: _aEffect, _bId: _bEffect};
      const orderOf = {_newId: _newOrder, _aId: _a, _bId: _b};
      final cover = <String, int>{};
      void count(String k) => cover[k] = (cover[k] ?? 0) + 1;
      for (var seed = 1; seed <= 250; seed++) {
        final rnd = Random(seed * 7919);
        final flights = <_Flight>[];
        final trace = <String>[];
        Failure fail() => rnd.nextBool() ? const Failure(message: 'x', statusCode: 500) : const NetworkFailure();
        Future<Either<Failure, T>> park<T>(String label, T Function() ok) {
          final c = Completer<Either<Failure, T>>();
          flights.add(_Flight(label, (good) => c.complete(good ? Right(ok()) : Left(fail()))));
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
        String why() => 'seed $seed\n${trace.join('\n')}';
        // R13-ADV-01 no fuzz: o detalhe X que um ato LONGO tirou da tela (a lista em loading) volta sem nenhum pedido de tela do operador
        int? replacedByLongOp;
        final sub = bloc.stream.listen((s) {
          if (s is ServiceOrderDetailState && replacedByLongOp == s.order.id) {
            count('resurrectedOverLongOp');
            trace.add('!! detalhe ${s.order.id} de volta por cima de um ato longo');
          }
          if (s is ServiceOrderDetailState || (s is ServiceOrderListState && !s.loading)) replacedByLongOp = null;
          states.add(s);
        });
        _Dialog? dialog;
        var pendingSeen = 0;
        var planSeen = 0;
        void add(ServiceOrderEvent e) {
          trace.add('${e.runtimeType}${e.props}');
          final shownNow = _shownOrNull(states);
          if (longOps.contains(e.runtimeType)) {
            if (shownNow is ServiceOrderDetailState) {
              replacedByLongOp = shownNow.order.id;
              // R15-SOC-04 (ii): o caso POSITIVO da cerca da D-F193 — o lote confirmado por cima do detalhe aberto, com uma leitura dele no ar
              count('longOpOverDetail');
              if (flights.any((f) => f.label == 'get ${shownNow.order.id}')) count('longOpOverDetailRereadInFlight');
            }
          } else if (e is ServiceOrderViewRequested || e is ServiceOrderOpenRequested || e is ServiceOrderListRequested ||
              e is ServiceOrderBackToListPressed) {
            replacedByLongOp = null;
          }
          if (!bloc.isClosed) bloc.add(e);                                              // o `_dispatch` da página (D-F184)
        }

        Future<void> completeOne({double okRate = 0.75}) async {
          var i = rnd.nextInt(flights.length);
          for (var retry = 0; retry < 2 && actKinds.contains(flights[i].kind) && flights.length > 1; retry++) {
            i = rnd.nextInt(flights.length);
          }
          final f = flights.removeAt(i);
          final ok = rnd.nextDouble() < okRate;
          final shownBefore = _shownOrNull(states);
          final at = states.length;
          trace.add('<- ${f.label} ${ok ? 'ok' : 'FAIL'}');
          f.finish(ok);
          await pumpEventQueue();
          if (f.kind == 'batch' || f.kind == 'transmit') {
            for (final s in states.sublist(at)) {
              if (s is ServiceOrderBatchInvoiceDone) {
                for (final e in s.report.results) {
                  expect(s.numbers[e.orderId], _numberOf[e.orderId], reason: 'relatório do lote com o número errado — ${why()}');
                }
                count('batchReport');
              }
              if (s is ServiceOrderFiscalBatchDone) {
                expect(s.noteNumbers, {_aId: _aNote}, reason: 'lote fiscal sem o nº da nota — ${why()}');
                count('fiscalReport');
              }
            }
          }
          if (!actKinds.contains(f.kind)) return;
          final onOwn = shownBefore is ServiceOrderDetailState && shownBefore.order.id == f.os;
          final onTheWay = shownBefore is! ServiceOrderDetailState &&
              flights.any((x) => x.label == 'get ${f.os}' || x.label == 'voice ${f.os}' || x.label == 'effect ${f.os}');
          var planShown = false;
          for (final s in states.sublist(at)) {
            final (isOutcome, about) = _outcome(s);
            if (isOutcome) {
              count(about == null ? 'outcomeOnOwn' : 'outcomeElsewhere');
              final reason = 'desfecho de ${f.label} com o número errado (tela: ${shownBefore.runtimeType}'
                  '${shownBefore is ServiceOrderDetailState ? ' ${shownBefore.order.id}' : ''}) — ${why()}';
              if (onTheWay) {
                expect(about == null || about == _numberOf[f.os], isTrue, reason: reason);
              } else {
                expect(about, onOwn ? isNull : _numberOf[f.os], reason: reason);
              }
              if (about != null) expect(about, isNot(f.os), reason: 'o desfecho levou o ID interno — ${why()}');
            }
            if (s is ServiceOrderCancelPlanReady) {
              planShown = true;
              expect(s.plan.orderId, f.os, reason: 'o plano de OUTRA OS — ${why()}');
            }
          }
          // R13-ADV-02 no fuzz: o plano OK da OS a caminho descartado em silêncio
          if (f.kind == 'plan' && ok && !planShown && onTheWay && !states.sublist(at).any((s) => _outcome(s).$1)) {
            count('planDroppedOnTheWay');
          }
        }

        add(const ServiceOrderListRequested(status: 'A', filter: ''));                 // o initState
        await pumpEventQueue();
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
              add(const ServiceOrderListRequested(status: 'A', filter: ''));
            } else if (pick < 85) {
              dialog = null;
              add(d.decision);
            } else if (pick < 95) {
              dialog = null;
            }
            await pumpEventQueue();
            continue;
          }
          final plans = states.whereType<ServiceOrderCancelPlanReady>().toList();
          if (plans.length > planSeen) {
            planSeen = plans.length;
            final plan = plans.last.plan;
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
            add(const ServiceOrderListRequested(status: 'A', filter: ''));
          } else if (shown is ServiceOrderDetailState) {
            if (shown.saving) {
              // botões travados — esperar
            } else if (pick < 15) {
              add(const ServiceOrderBackToListPressed());
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
                add([
                  ServiceOrderTransmitRequested(id),
                  ServiceOrderTransmitRequested(id),
                  ServiceOrderFiscalRefreshRequested(id),
                  ServiceOrderFiscalXmlRequested(id),
                  ServiceOrderFiscalDanfseRequested(id),
                  ServiceOrderCancelFlowRequested(id),
                ][r - 1]);
              }
            }
          } else if (shown is ServiceOrderListState) {
            if (shown.loading) {
              final waitingDetail = trace.lastWhere((t) => !t.startsWith('<-'), orElse: () => '').startsWith('ServiceOrderViewRequested');
              if (waitingDetail && pick < 90) {
                // esperar
              } else if (pick < 35) {
                add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
              } else if (pick < 45) {
                dialog = _Dialog(const ServiceOrderOpenRequested(5));                     // o FAB (lookup de cliente) — nunca travado
              }
            } else if (pick < 60) {
              final inAir = flights.where((f) => actKinds.contains(f.kind) && (f.os == _aId || f.os == _bId)).map((f) => f.os!).toList();
              add(ServiceOrderViewRequested(inAir.isNotEmpty && rnd.nextBool()
                  ? inAir[rnd.nextInt(inAir.length)]
                  : [_aId, _bId, _aId, _bId, _newId][rnd.nextInt(5)]));
            } else if (pick < 64) {
              dialog = _Dialog(const ServiceOrderOpenRequested(5));
            } else if (pick < 72) {
              add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
            } else if (pick < 77) {
              dialog = _Dialog(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
            } else if (pick < 85) {
              add(const ServiceOrderFiscalPendingRequested());
            } else if (pick < 90 && shown.items.any((i) => i.id == _newId)) {
              // a seleção do lote só existe sobre a lista CARREGADA que mostra a OS (a página limpa `_selected` quando o escopo muda) —
              // sem isto o fuzz despachava o lote de uma OS que a tela nunca mostrou (a semente 129: a 1ª lista FALHOU) e o relatório
              // caía no `?? orderId` do `_shownNumberOf`, um caminho que a UI não alcança
              dialog = _Dialog(const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input));
            }
          }
          await pumpEventQueue();
        }

        dialog = null;
        for (var guard = 0; flights.isNotEmpty; guard++) {
          expect(guard, lessThan(3000), reason: 'seed $seed não drena');
          await completeOne(okRate: 0.85);
        }
        await pumpEventQueue(times: 20);
        final rest = _shown(states);
        if (rest is ServiceOrderListState) {
          expect(rest.loading, isFalse, reason: 'spinner preso no repouso — ${why()}');
        } else if (rest is ServiceOrderDetailState) {
          expect(rest.saving, isFalse, reason: 'saving preso no repouso — ${why()}');
          expect(rest.fiscal == null || rest.fiscal == voiceOf[rest.order.id], isTrue, reason: 'voz de OUTRA OS — ${why()}');
        }
        for (final s in states.whereType<ServiceOrderDetailState>()) {
          final id = s.order.id;
          expect((s.fiscal == null || s.fiscal == voiceOf[id]) && (s.effect == null || s.effect == effectOf[id]), isTrue,
              reason: 'detalhe $id emitido com a voz/efeito de OUTRA OS — ${why()}');
        }
        await sub.cancel();
        await bloc.close();
      }
      // ignore: avoid_print
      print('cobertura do fuzz R13: $cover');
      const minimum = {'outcomeOnOwn': 300, 'outcomeElsewhere': 100, 'recreatedUnderDialog': 100, 'batchReport': 5, 'fiscalReport': 5};
      for (final e in minimum.entries) {
        expect(cover[e.key] ?? 0, greaterThan(e.value), reason: 'o fuzz quase não exercitou "${e.key}": $cover');
      }
      // R14-SOC-03 (gate socrático da Rodada 14): com a D-F193 e a D-F194 em vigor, os dois contadores que eram só impressos viram CERCA —
      // um detalhe ressuscitado sobre operação longa ou um plano da OS a caminho descartado reprova o fuzz
      expect([cover['resurrectedOverLongOp'] ?? 0, cover['planDroppedOnTheWay'] ?? 0], [0, 0], reason: 'D-F193/D-F194: $cover');
      // R15-SOC-04 (ii) (gate socrático da Rodada 15): a cerca acima não passa por vacuidade — o fuzz confirmou lotes POR CIMA do detalhe
      // aberto (as sementes são fixas: o número é estável). O caso com a releitura do detalhe NO AR (`longOpOverDetailRereadInFlight`,
      // impresso) é raro no gerador; quem o prova é o grupo dirigido do R13-ADV-01 acima (`rereadInFlightThenLoteConfirmed`)
      expect(cover['longOpOverDetail'] ?? 0, greaterThan(2), reason: 'o fuzz quase não confirmou lote sobre detalhe: $cover');
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
