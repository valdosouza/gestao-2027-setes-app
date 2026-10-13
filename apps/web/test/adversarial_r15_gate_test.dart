// GATE ADVERSARIAL independente do DELTA da Rodada 15 da F2b (setes-app) — alvo: `822fdf9..95d829d` (branch f2b):
// R14-SOC-05 (endurecimento do gate socrático da Rodada 14): `_beginDetailAct(emit, orderId)` só marca `saving` no detalhe DA OS do ato;
// `_outcomeOrder(orderId)` = `_showsOrder(orderId) ? null : _shownNumberOf(orderId)` (antes: `_stillOnDetail(screen) ||
// _showsOrder(orderId)` — "a tela não mudou" também tirava o prefixo). D-F196 (o plano fora da OS some sem aviso), D-F197 (o ato nascido
// com a OS a caminho não marca `saving`) e D-F198 (one-shots iguais seguidos viram um) são limites ACEITOS — não reabertos aqui. R14-SOC-03
// (a cerca do fuzz R13) roda no próprio gate R13.
//
// O que o delta PROMETE e este gate ataca: (i) o desfecho sai SEM prefixo exatamente quando a tela de agora é (ou vai ser) a OS do ato e
// com o NÚMERO dela senão — nas 7 telas possíveis × 13 atos × 3 desfechos; (ii) o `saving` só marca a OS do ato; (iii) nada alcançável pela
// página muda (o endurecimento é latente — "hoje todo ato nasce no detalhe dele"); (iv) "a garantia passa a ser do BLOC" — atacada com
// eventos DIRETOS (uma OS que não é a da tela), que é onde a regra antiga e a nova divergem.
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R15-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_r15_gate_test.dart
//   - `[FATO R15-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada ACHADO.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail (molde dos gates R9–R14).
//
// DEPOIS DO GATE (correções da sessão, 2026-10-13 — autorização em pé): D-F199 (= Q-F198-ADV-01 (a) = Q-F198-SOC-01 (a)) — UM predicado
// `_stillOnActDetail(screen, orderId)` no fim do ato e na troca de aba do Faturar; a guarda do plano e a lista depois de cancelar a OS pelo
// `_showsOrder` → os ACHADOs viraram `[CORRIGIDO D-F199]` e os FATOs de antes saíram; D-F201 (= Q-F198-ADV-02 (a)) — a cascata e a fronteira
// são `[DECIDIDO]` (conhecimento negativo no `_endDetailAct`). A assinatura `_outcomeOrder(orderId)` perdeu a tela (R15-SOC-05).

import 'dart:async';
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

/// Os NÚMEROS que a tela mostra PERMUTAM os ids (o número de cada OS é o id de OUTRA) — o molde dos gates R13/R14 (R12-ADV-06).
const _newId = 77;
const _aId = 7374;
const _bId = 8001;
const _numberOf = {_newId: 8001, _aId: 77, _bId: 7374};
const _newOrder = ServiceOrderFull(id: _newId, number: 8001, customerId: 5);
const _a = ServiceOrderFull(id: _aId, number: 77, customerId: 1, status: 'F');
const _b = ServiceOrderFull(id: _bId, number: 7374, customerId: 2, status: 'F');
const _orderOf = {_newId: _newOrder, _aId: _a, _bId: _b};
const _aVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
const _bVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 3);
const _voiceOf = {_aId: _aVoice, _bId: _bVoice};
const _aEffect = ServiceOrderFiscalEffect();
const _bEffect = ServiceOrderFiscalEffect(invoiceCancelled: true);
const _effectOf = {_aId: _aEffect, _bId: _bEffect};
const _aNote = '9001';

/// Recusa de REGRA (422 com código) — o 3º desfecho, ao lado do ok e do DESCONHECIDO (`NetworkFailure`).
const _refused = Failure(message: 'recusada', statusCode: 422, code: 'R15_REFUSED');
const _authorizedBlocks = [
  CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
];
const _reconfirmBlocks = [
  CancelPlanBlock(field: 'fiscal', message: 'reconferir', barrier: FiscalBarrier(kind: FiscalBarrierKind.reconfirm)),
];

/// Os 13 atos NO detalhe: 9 da OS faturada (a A; a "outra" é a B) e 4 da OS aberta (a nova; a "outra" é a A).
const _fiscalActs = ['transmit', 'refresh', 'reconfirm', 'xml', 'danfse', 'plan', 'localCancel', 'authCancel', 'waiver'];
const _openActs = ['itemSave', 'itemRemove', 'invoice', 'cancelOs'];
const _results = ['ok', 'refused', 'unknown'];

ServiceOrderEvent _eventOf(String act, int id) => switch (act) {
      'transmit' => ServiceOrderTransmitRequested(id),
      'refresh' => ServiceOrderFiscalRefreshRequested(id),
      'reconfirm' => ServiceOrderFiscalReconfirmRequested(id),
      'xml' => ServiceOrderFiscalXmlRequested(id),
      'danfse' => ServiceOrderFiscalDanfseRequested(id),
      'plan' => ServiceOrderCancelFlowRequested(id),
      'localCancel' => ServiceOrderCancelConfirmed(orderId: id, reason: 'motivo', atAuthority: false),
      'authCancel' => ServiceOrderCancelConfirmed(orderId: id, reason: 'motivo', atAuthority: true),
      'waiver' => ServiceOrderFiscalCancelWaiverRequested(orderId: id, reason: 'manter'),
      'itemSave' => ServiceOrderItemSaveRequested(orderId: id, input: _item),
      'itemRemove' => ServiceOrderItemRemoveRequested(orderId: id, itemId: 1),
      'invoice' => ServiceOrderInvoiceRequested(orderId: id, input: _input),
      'cancelOs' => ServiceOrderCancelRequested(id),
      _ => throw ArgumentError(act),
    };

/// A OS do ato NO detalhe que o evento pede (null = não é ato no detalhe).
int? _actOsOf(ServiceOrderEvent e) => switch (e) {
      ServiceOrderTransmitRequested(:final orderId) => orderId,
      ServiceOrderFiscalRefreshRequested(:final orderId) => orderId,
      ServiceOrderFiscalReconfirmRequested(:final orderId) => orderId,
      ServiceOrderFiscalXmlRequested(:final orderId) => orderId,
      ServiceOrderFiscalDanfseRequested(:final orderId) => orderId,
      ServiceOrderCancelFlowRequested(:final orderId) => orderId,
      ServiceOrderCancelConfirmed(:final orderId) => orderId,
      ServiceOrderFiscalCancelWaiverRequested(:final orderId) => orderId,
      ServiceOrderItemSaveRequested(:final orderId) => orderId,
      ServiceOrderItemRemoveRequested(:final orderId) => orderId,
      ServiceOrderInvoiceRequested(:final orderId) => orderId,
      ServiceOrderCancelRequested(:final id) => id,
      _ => null,
    };

/// A TELA de agora quando o ato termina (o ato nasceu no detalhe ABERTO da OS dele).
enum _Screen { ownOpen, ownReopened, ownOnTheWay, otherOpen, otherOnTheWay, list, longOpOverDetail }

bool _isOwn(_Screen s) => s == _Screen.ownOpen || s == _Screen.ownReopened || s == _Screen.ownOnTheWay;

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

/// Um ATO no detalhe do fuzzer: a OS dele, se nasceu no detalhe ABERTO dela (botões livres), o nº do pedido de tela do operador de então
/// e se nasceu com OUTRO ato da mesma OS no ar (os botões estavam livres pela D-F191 (b) — a releitura de um ato antigo os reabriu).
class _ActRec {
  _ActRec(this.os, {required this.bornOnOpen, required this.opSeq, required this.siblingInFlight});
  final int os;
  final bool bornOnOpen;
  final int opSeq;
  final bool siblingInFlight;
}

/// Uma resposta EM VOO do fuzzer. [tag]: de onde a chamada nasceu (o 1º passo do cancelamento; o POST de QUAL "Abrir OS"; o ato nascido
/// com a OS a caminho — D-F197); [act]: o ato que a pediu (herdado pelas chamadas que o fim dela dispara — a saga, a releitura).
class _Flight {
  _Flight(this.label, this.finish, this.tag, this.act);
  final String label;
  final void Function(bool ok) finish;
  final String tag;
  final _ActRec? act;
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

  /// Cada leitura de uma OS pega o PRÓXIMO futuro da fila (ou a resposta imediata de sempre).
  late Map<int, List<Completer<Either<Failure, ServiceOrderFull>>>> getQueue;
  late Map<int, int> getCalls;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
  });

  /// Mocks NOVOS com as respostas imediatas de sempre (lista, leitura da OS, voz e efeito, abrir OS).
  void resetMocks() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    getQueue = {};
    getCalls = {};
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => Right(_page([_newId, _aId, _bId])));
    for (final id in _orderOf.keys) {
      when(() => repo.getById(id)).thenAnswer((_) {
        getCalls[id] = (getCalls[id] ?? 0) + 1;
        final q = getQueue[id];
        if (q != null && q.isNotEmpty) return q.removeAt(0).future;
        return Future.value(Right(_orderOf[id]!));
      });
    }
    for (final id in _voiceOf.keys) {
      when(() => nfse.getView(id)).thenAnswer((_) async => Right(_voiceOf[id]!));
      when(() => invoice.fiscalEffect(id)).thenAnswer((_) async => Right(_effectOf[id]!));
    }
    when(() => repo.open(5)).thenAnswer((_) async => const Right(_newId));
  }

  setUp(() {
    resetMocks();
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

  /// Estaciona a chamada que DECIDE o ato [act] na OS [id] e devolve quem a termina: 'ok', 'refused' (422 com código — recusa de regra)
  /// ou 'unknown' (sem resposta — `NetworkFailure`: o desfecho DESCONHECIDO dos atos no fisco).
  void Function(String) arm(String act, int id) {
    Either<Failure, T> res<T>(String r, T ok) => r == 'ok' ? Right(ok) : Left(r == 'unknown' ? const NetworkFailure() : _refused);
    switch (act) {
      case 'transmit':
        final c = Completer<Either<Failure, ServiceOrderTransmitResult>>();
        when(() => nfse.transmit(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, ServiceOrderTransmitResult(invoiceId: id, attempt: 1, accessKey: 'K')));
      case 'refresh':
        final c = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
        when(() => nfse.refresh(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, const ServiceOrderFiscalRefreshResult()));
      case 'reconfirm':
        final c = Completer<Either<Failure, ServiceOrderFiscalReconfirmResult>>();
        when(() => nfse.reconfirm(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, const ServiceOrderFiscalReconfirmResult(needed: true, verdict: 'provada')));
      case 'xml':
        final c = Completer<Either<Failure, String>>();
        when(() => nfse.xml(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, '<x/>'));
      case 'danfse':
        final c = Completer<Either<Failure, String>>();
        when(() => nfse.danfse(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, 'JVBE'));
      case 'plan':
        final c = Completer<Either<Failure, ServiceOrderCancelPlan>>();
        when(() => invoice.cancelPlan(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, ServiceOrderCancelPlan(orderId: id, cancellable: true)));
      case 'localCancel':
        final c = Completer<Either<Failure, ServiceOrderInvoiceCancelResult>>();
        when(() => invoice.cancel(id, any())).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, ServiceOrderInvoiceCancelResult(orderId: id, invoiceNumber: '9')));
      case 'authCancel':
        // a saga: o plano relido (já) → o fisco (ESTACIONADO) → a nota (já)
        when(() => invoice.cancelPlan(id)).thenAnswer((_) async => Right(ServiceOrderCancelPlan(orderId: id, blocks: _authorizedBlocks)));
        when(() => invoice.cancel(id, any()))
            .thenAnswer((_) async => Right(ServiceOrderInvoiceCancelResult(orderId: id, invoiceNumber: '9')));
        final c = Completer<Either<Failure, ServiceOrderFiscalCancelResult>>();
        when(() => nfse.cancel(id, any())).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, ServiceOrderFiscalCancelResult(invoiceId: id, warnings: const ['aviso'])));
      case 'waiver':
        final c = Completer<Either<Failure, ServiceOrderCancelWaiverResult>>();
        when(() => invoice.cancelWaiver(id, any())).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, ServiceOrderCancelWaiverResult(orderId: id)));
      case 'itemSave':
        final c = Completer<Either<Failure, int>>();
        when(() => repo.itemPost(id, any())).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, 1));
      case 'itemRemove':
        final c = Completer<Either<Failure, Unit>>();
        when(() => repo.itemDelete(id, 1)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, unit));
      case 'invoice':
        final c = Completer<Either<Failure, ServiceOrderInvoiceResult>>();
        when(() => repo.invoice(id, any())).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, const ServiceOrderInvoiceResult(invoiceNumber: '1')));
      case 'cancelOs':
        final c = Completer<Either<Failure, Unit>>();
        when(() => repo.cancel(id)).thenAnswer((_) => c.future);
        return (r) => c.complete(res(r, unit));
    }
    throw ArgumentError(act);
  }

  /// Leva a TELA de agora a [screen] com o ato da OS [own] no ar (o ato nasceu no detalhe ABERTO dela); devolve o que ficou estacionado
  /// (a OS a caminho, o lote) para drenar depois.
  Future<List<void Function()>> goTo(ServiceOrderBloc bloc, _Screen screen, int own, int other) async {
    final drains = <void Function()>[];
    Future<void> add(ServiceOrderEvent e) async {
      bloc.add(e);
      await pumpEventQueue(times: 20);
    }

    Future<void> onTheWay(int id) async {
      final g = parkNextGet(id);
      drains.add(() => g.complete(Right(_orderOf[id]!)));
      await add(ServiceOrderViewRequested(id));
    }

    const list = ServiceOrderListRequested(status: 'A', filter: '');   // a página recriada (cruzar 1100 px — D-F160)
    switch (screen) {
      case _Screen.ownOpen:
        break;
      case _Screen.ownReopened:
        await add(list);
        await add(ServiceOrderViewRequested(own));
      case _Screen.ownOnTheWay:
        await add(list);
        await onTheWay(own);
      case _Screen.otherOpen:
        await add(list);
        await add(ServiceOrderViewRequested(other));
      case _Screen.otherOnTheWay:
        await add(list);
        await onTheWay(other);
      case _Screen.list:
        await add(list);
      case _Screen.longOpOverDetail:
        // o lote fiscal confirmado POR CIMA do detalhe (D-F177): a tela vira a lista em loading SEM subir o contador
        final c = Completer<Either<Failure, ServiceOrderTransmitResult>>();
        when(() => nfse.transmit(_bId)).thenAnswer((_) => c.future);
        drains.add(() => c.complete(const Right(ServiceOrderTransmitResult(invoiceId: _bId, attempt: 1, accessKey: 'K'))));
        await add(const ServiceOrderFiscalTransmitBatchRequested([_bId]));
    }
    return drains;
  }

  // ---------------------------------------------------------------------
  // 1. `_outcomeOrder` × a tela de agora — a matriz dirigida (o que a página alcança)
  // ---------------------------------------------------------------------
  group('R14-SOC-05 — `_outcomeOrder` × a tela de agora (o que a página alcança)', () {
    test('[RESISTIU] a matriz 13 atos × 7 telas × 3 desfechos (ok / recusa 422 / desconhecido): o ato nasce no detalhe ABERTO da OS dele (o '
        'começo marca `saving` NELA — o delta não tirou isso); termina com a tela em: a OS dele aberta, reaberta, a caminho; OUTRA OS aberta, '
        'a caminho; a lista; a lista em loading por um lote confirmado por cima. Todo desfecho sai SEM prefixo exatamente nas 3 primeiras e '
        'com o NÚMERO da OS do ato ("OS 77:"/"OS 8001:", nunca o id) nas 4 outras; o plano abre o diálogo SE E SÓ SE a tela é a OS dele '
        '(D-F194) e fora dela não emite NADA (D-F196); fora da OS dele o fim do ato não mexe na tela (nem lista, nem detalhe — D-F182/D-F193); '
        'dentro dela nunca o detalhe de outra OS e a lista só no cancelar OS/faturar (D-F182); no repouso nada preso (sem `saving`, sem '
        'spinner). A regra ANTIGA daria o MESMO em todas as 273 células (nas 4 "fora", o contador de tela subiu ou o detalhe saiu — '
        '`_stillOnDetail` já era falso): o endurecimento é latente no que a página alcança', () async {
      final wrong = <String>[];
      var cells = 0;
      for (final act in [..._fiscalActs, ..._openActs]) {
        final open = _openActs.contains(act);
        final own = open ? _newId : _aId;
        final other = open ? _aId : _bId;
        for (final screen in _Screen.values) {
          for (final r in _results) {
            final tag = '$act/${screen.name}/$r';
            resetMocks();
            final finish = arm(act, own);
            final (bloc, states, sub) = await start();
            bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));   // o initState
            await pumpEventQueue(times: 20);
            bloc.add(ServiceOrderViewRequested(own));
            await pumpEventQueue(times: 20);
            bloc.add(_eventOf(act, own));
            await pumpEventQueue(times: 20);
            final begin = _shown(states);
            if (!(begin is ServiceOrderDetailState && begin.order.id == own && begin.saving)) {
              wrong.add('$tag: o começo não marcou a OS do ato ($begin)');
            }
            final drains = await goTo(bloc, screen, own, other);
            final at = states.length;
            finish(r);
            await pumpEventQueue(times: 20);
            final step = states.sublist(at);
            final expected = _isOwn(screen) ? null : _numberOf[own];
            final outs = step.where((s) => _outcome(s).$1).toList();
            final plans = step.whereType<ServiceOrderCancelPlanReady>().length;
            if (act == 'plan' && r == 'ok') {
              if (plans != (_isOwn(screen) ? 1 : 0)) wrong.add('$tag: $plans diálogo(s) do plano');
              if (outs.isNotEmpty) wrong.add('$tag: o plano virou desfecho $outs');
            } else if (outs.isEmpty) {
              wrong.add('$tag: nenhum desfecho');
            }
            for (final o in outs) {
              if (_outcome(o).$2 != expected) wrong.add('$tag: ${o.runtimeType} com about=${_outcome(o).$2} (esperado $expected)');
            }
            final screens = step.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).toList();
            if (!_isOwn(screen) && screens.isNotEmpty) wrong.add('$tag: o fim do ato FORA da OS mexeu na tela: $screens');
            if (screens.whereType<ServiceOrderDetailState>().any((d) => d.order.id != own)) wrong.add('$tag: detalhe de OUTRA OS: $screens');
            final listAllowed = r == 'ok' && (act == 'cancelOs' || (act == 'invoice' && screen == _Screen.ownOpen));
            if (_isOwn(screen) && !listAllowed && screens.any((s) => s is ServiceOrderListState)) {
              wrong.add('$tag: a lista derrubou a OS do ato: $screens');
            }
            for (final d in drains) {
              d();
            }
            await pumpEventQueue(times: 20);
            final rest = _shown(states);
            if ((rest is ServiceOrderDetailState && rest.saving) || (rest is ServiceOrderListState && rest.loading)) {
              wrong.add('$tag: repouso preso $rest');
            }
            await sub.cancel();
            await bloc.close();
            cells++;
          }
        }
      }
      expect(cells, 13 * 7 * 3);
      expect(wrong, isEmpty, reason: wrong.take(8).join('\n'));
    });

    test('[RESISTIU] D-F197 × `_outcomeOrder`: o ato nascido com a OS A CAMINHO (as 3 decisões do diálogo do plano aberto sobre a lista — '
        'D-F194) não emite NADA no começo (nem `saving` — o limite aceito —, nem outra tela) e o desfecho segue a tela de agora: sem prefixo '
        'se a OS chegou ou segue a caminho, "OS 77:" se a tela virou a lista ou outra OS (3 atos × 4 telas × 3 desfechos); no repouso nada '
        'preso', () async {
      final wrong = <String>[];
      for (final act in const ['localCancel', 'authCancel', 'reconfirm']) {
        for (final end in const ['landed', 'stillOnTheWay', 'list', 'otherOpen']) {
          for (final r in _results) {
            final tag = '$act/$end/$r';
            resetMocks();
            final finish = arm(act, _aId);
            final (bloc, states, sub) = await start();
            bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
            await pumpEventQueue(times: 20);
            final g = parkNextGet(_aId);
            bloc.add(const ServiceOrderViewRequested(_aId));                                 // A a caminho
            await pumpEventQueue(times: 20);
            final at0 = states.length;
            bloc.add(_eventOf(act, _aId));                                                   // a decisão confirmada antes de A chegar
            await pumpEventQueue(times: 20);
            if (states.length != at0) wrong.add('$tag: o começo emitiu ${states.sublist(at0)}');
            switch (end) {
              case 'landed':
                g.complete(const Right(_a));
                await pumpEventQueue(times: 20);
              case 'list':
                bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
                await pumpEventQueue(times: 20);
              case 'otherOpen':
                bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
                await pumpEventQueue(times: 20);
                bloc.add(const ServiceOrderViewRequested(_bId));
                await pumpEventQueue(times: 20);
            }
            final at = states.length;
            finish(r);
            await pumpEventQueue(times: 20);
            final expected = end == 'landed' || end == 'stillOnTheWay' ? null : _numberOf[_aId];
            final outs = states.sublist(at).where((s) => _outcome(s).$1).toList();
            if (outs.isEmpty) wrong.add('$tag: nenhum desfecho');
            for (final o in outs) {
              if (_outcome(o).$2 != expected) wrong.add('$tag: ${o.runtimeType} com about=${_outcome(o).$2} (esperado $expected)');
            }
            if (!g.isCompleted) g.complete(const Right(_a));
            await pumpEventQueue(times: 20);
            final rest = _shown(states);
            if ((rest is ServiceOrderDetailState && rest.saving) || (rest is ServiceOrderListState && rest.loading)) {
              wrong.add('$tag: repouso preso $rest');
            }
            await sub.cancel();
            await bloc.close();
          }
        }
      }
      expect(wrong, isEmpty, reason: wrong.take(8).join('\n'));
    });

    test('[DECIDIDO D-F200 — Q-F198-SOC-02 (a), R15-SOC-03] a RECONFERÊNCIA nascida com a OS A CAMINHO (a porta da D-F194: o plano com '
        'barreira `reconfirm` aberto sobre a lista) não tem trava por nota: a OS chega com os botões abertos (sem `saving` — D-F197) e o 2º '
        'clique MANDA outra reconferência à nfse-api com a 1ª no ar. Aceito porque a DUPLICATA É INOFENSIVA (R16-SOC-01 — não porque o '
        'servidor serializa): um `GET /dps` no fisco sem efeito + o carimbo condicional da prova do E2404 (D-F90); só o fisco achar a nota '
        'passa pela trava da nota. Diferente do Transmitir/Cancelar/Manter (D-F183 — trava por nota)', () async {
      final calls = <Completer<Either<Failure, ServiceOrderFiscalReconfirmResult>>>[];
      when(() => nfse.reconfirm(_aId)).thenAnswer((_) {
        final c = Completer<Either<Failure, ServiceOrderFiscalReconfirmResult>>();
        calls.add(c);
        return c.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      final g = parkNextGet(_aId);
      bloc.add(const ServiceOrderViewRequested(_aId));                                       // A a caminho
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalReconfirmRequested(_aId));                            // a decisão do diálogo do plano
      await pumpEventQueue(times: 20);
      g.complete(const Right(_a));
      await pumpEventQueue(times: 20);
      final landed = _shown(states) as ServiceOrderDetailState;
      bloc.add(const ServiceOrderFiscalReconfirmRequested(_aId));                            // o 2º clique na OS que chegou
      await pumpEventQueue(times: 20);
      final inAir = calls.length;
      for (final c in calls) {
        c.complete(const Right(ServiceOrderFiscalReconfirmResult(needed: true, verdict: 'provada')));
      }
      await pumpEventQueue(times: 40);
      final rest = _shown(states);
      await sub.cancel();
      await bloc.close();
      expect([landed.order.id, landed.saving, inAir], [_aId, false, 2]);
      expect(rest is ServiceOrderDetailState && rest.order.id == _aId && !rest.saving, isTrue, reason: 'repouso: $rest');
    });
  });

  // ---------------------------------------------------------------------
  // 2. "A garantia passa a ser do BLOC" — eventos DIRETOS (uma OS que não é a da tela)
  // ---------------------------------------------------------------------
  group('R14-SOC-05 × evento DIRETO — onde a regra antiga e a nova divergem', () {
    /// A OS [other] na tela (ABERTA, ou a caminho no MESMO pedido de tela e chegada DEPOIS do começo do ato) e o ato [act] da OS [own]
    /// disparado DIRETO no bloc (a página nunca o despacha: todo callback do detalhe leva a OS da tela e os diálogos são modais).
    Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>, void Function(String), int)> actOverOther(
        String act, int own, int other, {bool landsAfterBegin = false}) async {
      final finish = arm(act, own);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      final g = landsAfterBegin ? parkNextGet(other) : null;
      bloc.add(ServiceOrderViewRequested(other));
      await pumpEventQueue(times: 20);
      final beforeAct = states.length;
      bloc.add(_eventOf(act, own));
      await pumpEventQueue(times: 20);
      final emittedAtBegin = states.length - beforeAct;
      if (g != null) {
        g.complete(Right(_orderOf[other]!));
        await pumpEventQueue(times: 20);
      }
      return (bloc, states, sub, finish, emittedAtBegin);
    }

    test('[RESISTIU] o ato da OS A com a OS B ABERTA — e com a B a caminho no MESMO pedido de tela, chegada depois do começo — (13 atos × 3 '
        'desfechos × 2): o começo NÃO emite nada (o detalhe da B nunca ganha `saving` de um ato que não é dela) e todo desfecho leva o '
        'NÚMERO da OS do ato. A regra ANTIGA dava SEM prefixo aqui (`_stillOnDetail(screen)` verdadeiro — o mesmo pedido de tela, o '
        'detalhe aberto): o desfecho da OS 77 lido como da OS 7374. A CORREÇÃO do delta, provada', () async {
      final wrong = <String>[];
      for (final lands in [false, true]) {
        for (final act in [..._fiscalActs, ..._openActs]) {
          final own = _openActs.contains(act) ? _newId : _aId;
          final other = _openActs.contains(act) ? _aId : _bId;
          for (final r in _results) {
            final tag = '$act/$r/lands=$lands';
            resetMocks();
            final (bloc, states, sub, finish, emittedAtBegin) = await actOverOther(act, own, other, landsAfterBegin: lands);
            if (emittedAtBegin != 0) wrong.add('$tag: o começo emitiu ${states.sublist(states.length - emittedAtBegin)}');
            final landed = _shown(states);
            if (!(landed is ServiceOrderDetailState && landed.order.id == other && !landed.saving)) wrong.add('$tag: a outra OS $landed');
            final at = states.length;
            finish(r);
            await pumpEventQueue(times: 20);
            final outs = states.sublist(at).where((s) => _outcome(s).$1).toList();
            if (!(act == 'plan' && r == 'ok') && outs.isEmpty) wrong.add('$tag: sem desfecho');
            for (final o in outs) {
              if (_outcome(o).$2 != _numberOf[own]) wrong.add('$tag: ${o.runtimeType} com about=${_outcome(o).$2}');
            }
            await sub.cancel();
            await bloc.close();
          }
        }
      }
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    // --- R15-ADV-01: as decisões que ainda leem "a tela não mudou" sem a OS do ato -------------------------------------------------

    test('[CORRIGIDO D-F199 — era o ACHADO R15-ADV-01 LOW] (a) o plano da OS A que chega com a OS B na tela NÃO abre — a D-F196 ("com a tela em OUTRA OS o plano some '
        'sem aviso") vale também quando o pedido de tela é o mesmo: a decisão de cancelar só abre sobre a OS que ela cancela (R10-SOC-03)', () async {
      for (final lands in [false, true]) {
        resetMocks();
        final (bloc, states, sub, finish, _) = await actOverOther('plan', _aId, _bId, landsAfterBegin: lands);
        final at = states.length;
        finish('ok');
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        expect(states.sublist(at).whereType<ServiceOrderCancelPlanReady>(), isEmpty, reason: 'lands=$lands');
      }
    });

    test('[CORRIGIDO D-F199 — era o ACHADO R15-ADV-01 LOW] (b)/(c) o fim do "Cancelar OS"/"Faturar" da OS nova com OUTRA OS na tela deixa a tela onde está (só o '
        'desfecho "OS 8001: …" — D-F182: "outra OS ou a lista: o desfecho leva o NÚMERO"; a lista desatualizada não é relida)', () async {
      for (final act in const ['cancelOs', 'invoice']) {
        for (final lands in [false, true]) {
          resetMocks();
          final (bloc, states, sub, finish, _) = await actOverOther(act, _newId, _aId, landsAfterBegin: lands);
          final at = states.length;
          finish('ok');
          await pumpEventQueue(times: 20);
          await sub.cancel();
          await bloc.close();
          expect([states.sublist(at).whereType<ServiceOrderListState>().length, (_shown(states) as ServiceOrderDetailState).order.id],
              [0, _aId], reason: '$act lands=$lands');
        }
      }
    });

    /// A OS B ABERTA com um "Transmitir" DELA no fisco (`saving`); o XML da OS A disparado DIRETO termina ([r]).
    Future<(List<ServiceOrderState>, int, void Function(String), ServiceOrderBloc, StreamSubscription<ServiceOrderState>)> xmlOfAOverBTransmitting(
        String r) async {
      final transmitB = arm('transmit', _bId);
      final xmlA = arm('xml', _aId);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_bId));
      await pumpEventQueue(times: 20);
      expect([(_shown(states) as ServiceOrderDetailState).order.id, (_shown(states) as ServiceOrderDetailState).saving], [_bId, true]);
      bloc.add(const ServiceOrderFiscalXmlRequested(_aId));                                // direto: a OS A não está na tela
      await pumpEventQueue(times: 20);
      final at = states.length;
      xmlA(r);
      await pumpEventQueue(times: 20);
      return (states, at, transmitB, bloc, sub);
    }

    test('[CORRIGIDO D-F199 — era o ACHADO R15-ADV-01 LOW] (d) o fim de um ato da OS A nunca re-emite o detalhe da OS B — a B segue em `saving` até o desfecho do ato '
        'DELA', () async {
      for (final r in const ['ok', 'refused']) {
        resetMocks();
        final (states, at, transmitB, bloc, sub) = await xmlOfAOverBTransmitting(r);
        final shown = _shown(states) as ServiceOrderDetailState;
        final reemitted = states.sublist(at).whereType<ServiceOrderDetailState>().length;   // antes do desfecho do ato da B
        transmitB('ok');
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        expect([reemitted, shown.order.id, shown.saving], [0, _bId, true], reason: r);
      }
    });

    test('[DECIDIDO D-F201 — fronteira do R15-ADV-01] o 2º ato na MESMA OS em `saving` (disparado direto — na página os botões estão travados): o fim dele '
        're-emite a OS sem `saving` com o 1º ainda no fisco. NÃO é o R15-ADV-01 (é a mesma OS) e a correção sugerida para ele (conferir a OS '
        'do ato) NÃO o cobre: é a família da D-F191 (b)/D-F197 — o contador de atos POR OS do R14-ADV-01, recusado. Registrado para ninguém '
        'ler a correção do R15-ADV-01 como se fechasse isto', () async {
      final transmitA = arm('transmit', _aId);
      final xmlA = arm('xml', _aId);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalXmlRequested(_aId));
      await pumpEventQueue(times: 20);
      final at = states.length;
      xmlA('ok');
      await pumpEventQueue(times: 20);
      final reemitted = states.sublist(at).whereType<ServiceOrderDetailState>().single;
      transmitA('ok');
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([reemitted.order.id, reemitted.saving], [_aId, false]);
    });
  });

  // ---------------------------------------------------------------------
  // 3. `saving` pelo que a página alcança — a OS do ato reaberta, outra OS aberta no meio
  // ---------------------------------------------------------------------
  group('R14-SOC-05 — o `saving` pelo que a página alcança', () {
    test('[RESISTIU] 2º ato na MESMA OS (o único caminho da página: a OS reaberta sem `saving` — D-F191 (b)): o começo do 2º MARCA a OS '
        'reaberta (o `detail.id == orderId` novo não tirou isso) e o fim do 1º por RECUSA (sem releitura — `_endDetailAct` do pedido de tela '
        'velho) NÃO desmarca o 2º; o desfecho do 1º sai sem prefixo (a tela é a OS dele); o fim do 2º libera', () async {
      final refreshA = arm('refresh', _aId);
      final xmlA = arm('xml', _aId);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                            // ato 1
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // A reaberta (sem saving — D-F191 (b))
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isFalse);
      bloc.add(const ServiceOrderFiscalXmlRequested(_aId));                                // ato 2 na A reaberta
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue, reason: 'o 2º ato marca a OS reaberta');
      final at = states.length;
      refreshA('refused');                                                                 // o 1º termina por recusa
      await pumpEventQueue(times: 20);
      final step = states.sublist(at);
      expect([step.whereType<ServiceOrderDetailState>().length, (_shown(states) as ServiceOrderDetailState).saving], [0, true]);
      expect(step.whereType<ServiceOrderActionFailure>().single.orderNumber, isNull);
      xmlA('ok');
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).saving, isFalse);
    });

    test('[DECIDIDO D-F201 — R15-ADV-02, família D-F191 (b), achado pelo oráculo (7) do fuzz, semente 258] a CASCATA: ato 1 na A; página recriada; A '
        'reaberta (sem `saving` — D-F191 (b)); o ato 1 termina e a releitura dele fica no ar; ato 2 na A reaberta (`saving`); a releitura do '
        'ato 1 chega e REABRE os botões com o ato 2 no fisco (D-F191 (b), aceito); o operador dispara o ato 3 (`saving`); o ato 2 termina por '
        'recusa e o `_endDetailAct` dele — o MESMO pedido de tela do ato 3 — DESMARCA o ato 3, que segue no fisco. Alcançável pela página '
        '(todos os cliques num detalhe sem `saving`), anterior ao delta (nem o `_beginDetailAct` nem o `_endDetailAct` mudaram aqui) e da '
        'raiz já aceita: sem contador de atos POR OS (o R14-ADV-01 recusado na D-F197); quem protege a nota são as travas por nota e o '
        'servidor', () async {
      final refreshA = arm('refresh', _aId);
      final xmlA = arm('xml', _aId);
      final danfseA = arm('danfse', _aId);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                            // ato 1
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // A reaberta, sem saving
      await pumpEventQueue(times: 20);
      final reread = parkNextGet(_aId);
      refreshA('ok');                                                                      // o ato 1 termina — a releitura dele fica no ar
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isFalse);
      bloc.add(const ServiceOrderFiscalXmlRequested(_aId));                                // ato 2
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      reread.complete(const Right(_a));                                                    // a releitura do ato 1 reabre os botões (D-F191 (b))
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isFalse, reason: 'D-F191 (b)');
      bloc.add(const ServiceOrderFiscalDanfseRequested(_aId));                             // ato 3 — os botões estavam livres
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      final at = states.length;
      xmlA('refused');                                                                     // o ato 2 termina por recusa
      await pumpEventQueue(times: 20);
      final cleared = states.sublist(at).whereType<ServiceOrderDetailState>().single;
      danfseA('ok');
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([cleared.order.id, cleared.saving], [_aId, false], reason: 'o ato 3 (DANFSe) ainda no ar');
    });

    test('[RESISTIU] ato na OS A e a OS B aberta no meio (página recriada → abrir B): a B chega sem `saving` (nenhum ato dela), o ato DELA '
        'marca a B, e o fim do ato da A — ok (releitura) ou recusa (`_endDetailAct`) — não toca a B (nenhuma emissão de tela) e sai com "OS '
        '77:"; o fim do ato da B libera a B', () async {
      for (final r in _results) {
        resetMocks();
        final refreshA = arm('refresh', _aId);
        final transmitB = arm('transmit', _bId);
        final (bloc, states, sub) = await start();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderViewRequested(_aId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderViewRequested(_bId));
        await pumpEventQueue(times: 20);
        expect([(_shown(states) as ServiceOrderDetailState).order.id, (_shown(states) as ServiceOrderDetailState).saving], [_bId, false], reason: r);
        bloc.add(const ServiceOrderTransmitRequested(_bId));
        await pumpEventQueue(times: 20);
        expect((_shown(states) as ServiceOrderDetailState).saving, isTrue, reason: r);
        final at = states.length;
        refreshA(r);
        await pumpEventQueue(times: 20);
        final step = states.sublist(at);
        expect(step.where((s) => s is ServiceOrderDetailState || s is ServiceOrderListState), isEmpty, reason: r);
        expect(step.where((s) => _outcome(s).$1).map((s) => _outcome(s).$2).toSet(), {_numberOf[_aId]}, reason: r);
        expect((_shown(states) as ServiceOrderDetailState).saving, isTrue, reason: '$r: a B segue em saving');
        transmitB('ok');
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        expect([(_shown(states) as ServiceOrderDetailState).order.id, (_shown(states) as ServiceOrderDetailState).saving], [_bId, false], reason: r);
      }
    });
  });

  // ---------------------------------------------------------------------
  // 4. Fuzz — o modelo do último pedido de tela (molde R14) + o `saving` POR OS + o diferencial da regra antiga
  // ---------------------------------------------------------------------

  /// O fuzz do gate R14 com: os 13 atos (reconferir pelo diálogo do plano; remover item), a recusa 422 ao lado do desconhecido, e três
  /// oráculos novos — (6) `saving: true` só no começo de um ato DA OS do detalhe; (7) `saving: false` com um ato da OS no ar que nasceu no
  /// detalhe ABERTO dela, sem pedido de tela do operador desde então, só pela releitura de um ato ANTIGO na OS reaberta (D-F191 (b)); (8) os
  /// contadores do diferencial `beginOnOtherDetail` (o ato começou com OUTRA OS no detalhe — onde o `_beginDetailAct` antigo marcava a outra)
  /// e `oldRuleMayDiffer` (desfecho fora da OS com o detalhe de OUTRA OS na tela e nenhum pedido de tela do operador desde o começo do ato —
  /// condição NECESSÁRIA para a regra antiga dar sem prefixo). [direct]: além do que a página despacha, atos disparados direto em qualquer
  /// OS (também com a tela em outra OS e com a OS em `saving`) — as manifestações do R15-ADV-01 são CONTADAS, não reprovadas.
  Future<Map<String, int>> fuzz({required bool direct, required int seeds}) async {
    final cover = <String, int>{};
    void count(String k) => cover[k] = (cover[k] ?? 0) + 1;
    const actKinds = {'transmit', 'refresh', 'reconfirm', 'xml', 'danfse', 'plan', 'nfsecancel', 'localcancel', 'waiver', 'item', 'itemrm',
        'invoice', 'cancelOs'};
    const longOps = {ServiceOrderFiscalTransmitBatchRequested, ServiceOrderBatchInvoiceRequested, ServiceOrderMonthlyRunRequested,
        ServiceOrderFiscalPendingRequested};
    for (var seed = 1; seed <= seeds; seed++) {
      final rnd = Random(seed * (direct ? 15485863 : 104723));
      final flights = <_Flight>[];
      final trace = <String>[];
      final seen = <int>{};   // as OS que a tela já mostrou (lista ou detalhe)
      // o MODELO do último pedido de tela do operador
      var last = 'list'; // list | longOp | view | open | detail
      int? os;
      var openSeq = 0;
      var opSeq = 0;   // nº de pedidos de TELA do operador (lista/voltar/ver/abrir)
      // o passo corrente
      var stepKind = 'add';
      ServiceOrderEvent? stepEvent;
      _Flight? stepFlight;
      _ActRec? stepAct;
      var stepHadOutcome = false;
      ServiceOrderState? stepStartState;
      var stepEmits = 0;     // R16-SOC-02: as emissões do passo (o desfecho engolido exige a lista como 1ª)
      var stepOk = true;     // R16-ADV-02: o desfecho do passo de completar (a causa do desfecho engolido é um get/post que FALHOU)
      var stepPlanShown = false;
      final violations = <String>[];
      String why() => 'seed $seed (direct=$direct)\n${trace.join('\n')}';
      _ActRec? actNow() => stepKind == 'add' ? stepAct : stepFlight?.act;
      String tagNow() {
        final e = stepEvent;
        final f = stepFlight;
        if (stepKind == 'add' && e is ServiceOrderCancelFlowRequested) return 'flow';
        if (stepKind == 'add' && e is ServiceOrderOpenRequested) return 'open$openSeq';
        if (stepKind == 'add' && last == 'view' && e != null && _actOsOf(e) == os) return 'onTheWay';
        if (stepKind == 'complete' && f != null && f.tag == 'onTheWay') return 'onTheWay';
        return '';
      }

      Failure fail() => switch (rnd.nextInt(3)) {
            0 => const Failure(message: 'x', statusCode: 500),
            1 => const NetworkFailure(),
            _ => _refused,
          };
      Future<Either<Failure, T>> park<T>(String label, T Function() ok) {
        final c = Completer<Either<Failure, T>>();
        flights.add(_Flight(label, (good) => c.complete(good ? Right(ok()) : Left(fail())), tagNow(), actNow()));
        return c.future;
      }

      repo = ServiceOrderRepoMock();
      nfse = NfseRepoMock();
      invoice = InvoiceRepoMock();
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) => park('list', () => _page([_newId, _aId, _bId])));
      for (final id in _orderOf.keys) {
        when(() => repo.getById(id)).thenAnswer((_) => park('get $id', () => _orderOf[id]!));
      }
      for (final id in _voiceOf.keys) {
        when(() => nfse.getView(id)).thenAnswer((_) => park('voice $id', () => _voiceOf[id]!));
        when(() => invoice.fiscalEffect(id)).thenAnswer((_) => park('effect $id', () => _effectOf[id]!));
        when(() => nfse.refresh(id)).thenAnswer((_) => park('refresh $id', () => const ServiceOrderFiscalRefreshResult()));
        when(() => nfse.reconfirm(id))
            .thenAnswer((_) => park('reconfirm $id', () => ServiceOrderFiscalReconfirmResult(needed: true, found: rnd.nextBool(), verdict: 'provada')));
        when(() => nfse.xml(id)).thenAnswer((_) => park('xml $id', () => '<x/>'));
        when(() => nfse.danfse(id)).thenAnswer((_) => park('danfse $id', () => 'JVBE'));
        when(() => invoice.cancelPlan(id)).thenAnswer((_) => park('plan $id', () => switch (rnd.nextInt(3)) {
              0 => ServiceOrderCancelPlan(orderId: id, cancellable: true),
              1 => ServiceOrderCancelPlan(orderId: id, blocks: _authorizedBlocks),
              _ => ServiceOrderCancelPlan(orderId: id, blocks: _reconfirmBlocks),
            }));
        when(() => nfse.cancel(id, any()))
            .thenAnswer((_) => park('nfsecancel $id', () => ServiceOrderFiscalCancelResult(invoiceId: id, warnings: const ['aviso'])));
        when(() => invoice.cancel(id, any()))
            .thenAnswer((_) => park('localcancel $id', () => ServiceOrderInvoiceCancelResult(orderId: id, invoiceNumber: '9')));
        when(() => invoice.cancelWaiver(id, any())).thenAnswer((_) => park('waiver $id', () => ServiceOrderCancelWaiverResult(orderId: id)));
      }
      when(() => nfse.transmit(any())).thenAnswer((inv) {
        final id = inv.positionalArguments[0] as int;
        return park('transmit $id', () => ServiceOrderTransmitResult(invoiceId: id, attempt: 1, accessKey: 'K'));
      });
      when(() => repo.open(5)).thenAnswer((_) => park('post', () => _newId));
      when(() => repo.itemPost(_newId, any())).thenAnswer((_) => park('item $_newId', () => 1));
      when(() => repo.itemDelete(_newId, 1)).thenAnswer((_) => park('itemrm $_newId', () => unit));
      when(() => repo.invoice(_newId, any())).thenAnswer((_) => park('invoice $_newId', () => const ServiceOrderInvoiceResult(invoiceNumber: '1')));
      when(() => repo.cancel(_newId)).thenAnswer((_) => park('cancelOs $_newId', () => unit));
      when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
      when(() => repo.batchInvoice(any(), any()))
          .thenAnswer((_) => park('batch', () => BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: _newId, ok: true)])));
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => park('pending',
          () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: _aNote)], page: 1, pageSize: 100, total: 1)));

      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      bool onWay() => last == 'view' || last == 'open';
      final sub = bloc.stream.listen((s) {
        final before = _shownOrNull(states);   // a tela ANTES desta emissão
        states.add(s);
        stepEmits++;
        if (s is ServiceOrderListState) seen.addAll(s.items.map((i) => i.id));
        if (s is ServiceOrderDetailState) seen.add(s.order.id);
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
            final a = f.act;
            if (!own && before is ServiceOrderDetailState && before.order.id != f.os && a != null && a.opSeq == opSeq) count('oldRuleMayDiffer');
          }
        }
        if (s is ServiceOrderCancelPlanReady) stepPlanShown = true;
        if (s is ServiceOrderDetailState) {
          final id = s.order.id;
          final act = actNow();
          // (6) `saving: true` só no começo de um ato DA OS do detalhe
          if (s.saving && !(stepKind == 'add' && act != null && act.os == id)) {
            violations.add('(6) detalhe $id com saving:true fora do começo de um ato DELE (passo $stepKind, ato da OS ${act?.os}) — ${why()}');
          }
          // (7) `saving: false` com um ato DELE no ar, nascido no detalhe ABERTO dele, sem pedido de tela do operador desde então
          if (!s.saving) {
            final live = flights
                .where((x) => actKinds.contains(x.kind) && x.act != null && x.act != act && x.act!.os == id && x.act!.bornOnOpen && x.act!.opSeq == opSeq)
                .toList();
            if (live.isNotEmpty) {
              if (act != null && act.os == id && act.opSeq < live.first.act!.opSeq) {
                count('D-F191b savingCleared');   // a releitura de um ato ANTIGO na mesma OS reaberta (limite aceito)
              } else if (act != null && act.os == id && live.every((x) => x.act!.siblingInFlight)) {
                // R15-ADV-02 (a CASCATA da D-F191 (b)): o ato nasceu com os botões reabertos pela releitura de um ato antigo, com OUTRO
                // ato da mesma OS no ar — o fim desse outro (`_endDetailAct`, mesmo pedido de tela) o desmarca
                count('R15-ADV-02 cascadeSavingCleared');
              } else if (direct && act != null && act.os != id) {
                count('R15-ADV-01d savingClearedByOtherOsAct');
              } else if (direct && act != null) {
                count('sameOsSecondAct savingCleared');   // 2º ato na OS em saving — só por evento direto (os botões travam)
              } else {
                violations.add('(7) detalhe $id sem saving com o ato ${live.first.label} DELE no ar (passo $stepKind, ato da OS ${act?.os}) — ${why()}');
              }
            }
          }
          // (1) nenhum detalhe fora do modelo
          if (!((last == 'view' || last == 'open' || last == 'detail') && os == id)) {
            if (last == 'longOp') count('resurrectedOverLongOp');
            violations.add('(1) detalhe $id emitido com o modelo em $last $os — ${why()}');
          } else if (onWay()) {
            final inFlight = flights.where((x) => actKinds.contains(x.kind) && x.os == id).toList();
            if (!s.saving && inFlight.isNotEmpty) {
              count(inFlight.any((x) => x.tag == 'onTheWay') ? 'D-F197 landedWithoutSaving' : 'D-F191b landedWithoutSaving');
            }
            last = 'detail';
          }
        } else if (s is ServiceOrderListState) {
          if (stepKind == 'complete') {
            if (onWay() || last == 'detail') {
              final act = actNow();
              if (last == 'detail' && act != null && act.os != os) {
                if (direct) {
                  count('R15-ADV-01bc listOverOtherByAct');
                } else {
                  violations.add('lista emitida pelo fim do ato da OS ${act.os} com a OS $os aberta — ${why()}');
                }
              }
              final startState = stepStartState;
              final swallowCause = stepKind == 'complete' && !stepOk && const {'get', 'post'}.contains(stepFlight?.kind);
              if (!stepHadOutcome && startState is ServiceOrderActionFailure && stepEmits == 1 && swallowCause) {
                count('D-F198 outcomeSwallowed');   // o desfecho do passo era IGUAL ao estado atual e o bloc o engoliu (limite aceito)
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
          opSeq++;
        } else if (e is ServiceOrderViewRequested) {
          last = 'view';
          os = e.id;
          opSeq++;
        } else if (e is ServiceOrderOpenRequested) {
          last = 'open';
          os = null;   // o id só com o POST (D-F191)
          openSeq++;
          opSeq++;
        }
        final before = _shownOrNull(states);
        final actOs = _actOsOf(e);
        stepAct = actOs == null
            ? null
            : _ActRec(actOs,
                bornOnOpen: last == 'detail' && os == actOs && before is ServiceOrderDetailState && before.order.id == actOs && !before.saving,
                opSeq: opSeq,
                // R16-ADV-03 (gate adversarial da Rodada 16): o irmão em voo é QUALQUER parte da cadeia de outro ato da mesma OS (a chamada
                // decisiva, a releitura, a voz, o efeito) — só a decisiva reprovava por engano a cascata da D-F201 vinda da saga a caminho
                siblingInFlight: flights.any((x) => x.act != null && x.act!.os == actOs));
        if (actOs != null && before is ServiceOrderDetailState && before.order.id != actOs) count('beginOnOtherDetail');
        stepKind = 'add';
        stepOk = true;
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
        stepOk = ok;
        final planOwn = (last == 'view' || last == 'detail') && os == f.os;
        if (f.kind == 'post' && ok && last == 'open' && f.tag == 'open$openSeq') os = _newId;   // a OS a caminho ganha o id
        final at = states.length;
        trace.add('<- ${f.label}${f.tag.isEmpty ? '' : ' [${f.tag}]'} ${ok ? 'ok' : 'FAIL'}');
        stepKind = 'complete';
        stepEvent = null;
        stepFlight = f;
        stepAct = null;
        stepHadOutcome = false;
        stepEmits = 0;
        stepPlanShown = false;
        stepStartState = states.lastOrNull;
        f.finish(ok);
        await pumpEventQueue();
        if (actKinds.contains(f.kind) && f.act != null) count('done ${f.kind}');
        // (3) o 1º passo do cancelamento: o diálogo SE E SÓ SE o modelo é a OS dele (aberta ou a caminho)
        if (f.kind == 'plan' && f.tag == 'flow' && ok) {
          count(planOwn ? 'planOnOwn' : 'planElsewhere');
          if (stepPlanShown && !planOwn) {
            if (direct) {
              count('R15-ADV-01a planOverOther');
            } else {
              violations.add('(3) plano de ${f.os} abriu com o modelo em $last $os — ${why()}');
            }
          } else if (!stepPlanShown && planOwn) {
            final startState = stepStartState;
            if (startState is ServiceOrderCancelPlanReady && startState.plan.orderId == f.os) {
              // D-F198: o plano IGUAL ao estado atual (o 1º plano da mesma OS, sem emissão no meio — a OS a caminho) é engolido pelo bloc;
              // o diálogo do 1º já está aberto (só por evento direto: na página o 2º "Cancelar nota" exige o detalhe)
              count('D-F198 planSwallowed');
            } else {
              violations.add('(3) plano de ${f.os} NÃO abriu com o modelo nele ($last $os) — ${why()}');
            }
          }
          if (!planOwn && states.sublist(at).any((s) => _outcome(s).$1)) violations.add('(3) plano fora da OS dele virou one-shot — ${why()}');
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
        if (direct && rnd.nextDouble() < 0.3) {
          // o ato DIRETO: qualquer OS que a tela JÁ mostrou (o número dela é conhecido — D-F187), qualquer tela de agora (também com a OS
          // em saving e com um diálogo aberto)
          final pool = [_aId, _bId, _newId].where(seen.contains).toList();
          if (pool.isEmpty) continue;
          final target = pool[rnd.nextInt(pool.length)];
          final r = rnd.nextInt(target == _newId ? 4 : 8);
          count('directAct');
          await add(target == _newId
              ? const [
                  ServiceOrderItemSaveRequested(orderId: _newId, input: _item),
                  ServiceOrderItemRemoveRequested(orderId: _newId, itemId: 1),
                  ServiceOrderInvoiceRequested(orderId: _newId, input: _input),
                  ServiceOrderCancelRequested(_newId),
                ][r]
              : [
                  ServiceOrderTransmitRequested(target),
                  ServiceOrderCancelFlowRequested(target),
                  ServiceOrderFiscalRefreshRequested(target),
                  ServiceOrderFiscalReconfirmRequested(target),
                  ServiceOrderFiscalXmlRequested(target),
                  ServiceOrderFiscalDanfseRequested(target),
                  ServiceOrderCancelConfirmed(orderId: target, reason: 'motivo', atAuthority: rnd.nextBool()),
                  ServiceOrderFiscalCancelWaiverRequested(orderId: target, reason: 'manter'),
                ][r]);
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
            if (_actOsOf(d.decision) != null && onWay()) count('decisionWithOsOnTheWay');
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
          // a página (`_onCancelPlan`): reconferir → "Reconferir"; cancelável → motivo; NFS-e autorizada como único impedimento → no fisco
          dialog = _Dialog(plan.fiscalBarrier?.kind == FiscalBarrierKind.reconfirm
              ? ServiceOrderFiscalReconfirmRequested(plan.orderId)
              : ServiceOrderCancelConfirmed(orderId: plan.orderId, reason: 'motivo', atAuthority: plan.onlyAuthorityStands));
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
            dialog = _Dialog(const [
              ServiceOrderItemSaveRequested(orderId: _newId, input: _item),
              ServiceOrderItemRemoveRequested(orderId: _newId, itemId: 1),
              ServiceOrderInvoiceRequested(orderId: _newId, input: _input),
              ServiceOrderCancelRequested(_newId),
            ][rnd.nextInt(4)]);
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
        if (!((s.fiscal == null || s.fiscal == _voiceOf[id]) && (s.effect == null || s.effect == _effectOf[id]))) {
          violations.add('detalhe $id emitido com a voz/efeito de OUTRA OS — ${why()}');
        }
      }
      await sub.cancel();
      await bloc.close();
      expect(violations, isEmpty, reason: violations.isEmpty ? '' : violations.first);
    }
    return cover;
  }

  group('fuzz do bloc R15 — o modelo do último pedido de tela + o `saving` por OS + o diferencial da regra antiga', () {
    test('[RESISTIU] 300 sequências pelo que a PÁGINA despacha (o molde do fuzz R14 com os 13 atos — reconferir pelo diálogo do plano, '
        'remover item — e a recusa 422 ao lado do desconhecido): os oráculos (1)–(5) do R14 e os novos (6) `saving: true` só no começo de um '
        'ato da OS do detalhe, (7) nenhum `saving: false` sobre um ato da OS nascido no detalhe aberto dela, sem pedido de tela desde então, '
        'fora da releitura de um ato ANTIGO na OS reaberta (D-F191 (b)); e o DIFERENCIAL: `beginOnOtherDetail` = 0 e `oldRuleMayDiffer` = 0 '
        '— nenhum caminho da página chega onde a regra antiga e a nova divergem (o endurecimento é latente, nada alcançável mudou)', () async {
      final cover = await fuzz(direct: false, seeds: 300);
      // ignore: avoid_print
      print('cobertura do fuzz R15 (página): $cover');
      expect([cover['beginOnOtherDetail'] ?? 0, cover['oldRuleMayDiffer'] ?? 0], [0, 0], reason: 'R14-SOC-05: $cover');
      const minimum = {'outcomeOnOwn': 300, 'outcomeElsewhere': 100, 'recreatedUnderDialog': 100, 'batchReport': 5, 'fiscalReport': 5,
          'planOnOwn': 20, 'planElsewhere': 5, 'planDialogOverOnTheWay': 5, 'decisionWithOsOnTheWay': 1, 'done reconfirm': 5,
          'done itemrm': 5, 'done waiver': 5, 'done xml': 20, 'done danfse': 20, 'done cancelOs': 5, 'done invoice': 5};
      for (final e in minimum.entries) {
        expect(cover[e.key] ?? 0, greaterThan(e.value), reason: 'o fuzz quase não exercitou "${e.key}": $cover');
      }
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('[RESISTIU] 200 sequências com atos DIRETOS (qualquer OS, qualquer tela — também com a tela em OUTRA OS e com a OS em `saving`): o '
        'que o delta PROMETE vale no bloc — (4) todo desfecho sai sem prefixo SÓ com a tela na OS do ato e com o NÚMERO dela senão, (6) o '
        '`saving` só marca a OS do ato — e os oráculos (1), (2), (5) seguem. O diferencial é EXERCITADO (`beginOnOtherDetail`, '
        '`oldRuleMayDiffer` > 0 — onde a regra antiga marcava a outra OS e tirava o prefixo). CERCA da D-F199: as manifestações do R15-ADV-01 '
        '(a) plano sobre outra OS, (b)/(c) lista sobre outra OS, (d) `saving` da outra OS desmarcado = 0; contado (impresso, sem reprovar): o '
        '2º ato na MESMA OS em `saving` (a família D-F191 (b)/D-F197 — D-F201)', () async {
      final cover = await fuzz(direct: true, seeds: 200);
      // ignore: avoid_print
      print('cobertura do fuzz R15 (eventos diretos): $cover');
      expect(cover['directAct'] ?? 0, greaterThan(1000));
      expect(cover['beginOnOtherDetail'] ?? 0, greaterThan(20), reason: '$cover');
      expect(cover['oldRuleMayDiffer'] ?? 0, greaterThan(5), reason: '$cover');
      // D-F199 (correção da sessão): com o predicado único, as três manifestações do R15-ADV-01 viram CERCA — o plano da A sobre a B, a
      // lista sobre outra OS pelo fim de um ato e o `saving` da B desmarcado pelo fim de um ato da A reprovam o fuzz
      expect([cover['R15-ADV-01a planOverOther'] ?? 0, cover['R15-ADV-01bc listOverOtherByAct'] ?? 0, cover['R15-ADV-01d savingClearedByOtherOsAct'] ?? 0],
          [0, 0, 0], reason: 'D-F199: $cover');
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}
