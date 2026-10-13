// GATE ADVERSARIAL independente do DELTA da Rodada 16 da F2b (setes-app) — alvo: `95d829d..41f8867` (branch f2b, commits 7bbbd04 e 41f8867):
// D-F199 — UM predicado `_stillOnActDetail(screen, orderId)` ("a tela capturada ainda é o detalhe DESTA OS") no `_endDetailAct` e na troca
// de aba do Faturar; a guarda do plano e a recarga da lista depois do "Cancelar OS" pelo `_showsOrder(orderId)`; `_outcomeOrder(orderId)` e
// `_unknownOutcome` sem a tela capturada (R15-SOC-05). D-F200/D-F201 são conhecimento negativo ACEITO — não reabertos aqui. Junto: os
// oráculos apertados dos gates R13/R14 (R15-SOC-04) e o `apps/web/.gitignore` em UTF-8 (o `flutter build web` quebrava na migração
// ScrubGeneratedPluginRegistrant do flutter_tools).
//
// O que o delta PROMETE e este gate ataca: (i) nada alcançável pela PÁGINA muda (o endurecimento é latente — "hoje todo ato nasce no
// detalhe dele"); (ii) com eventos DIRETOS, o fim de um ato da A nunca re-emite o detalhe de OUTRA OS, nunca tira o operador de outra OS
// (nem a lista, nem o plano) e nunca desmarca o `saving` dela; (iii) o que precisa CONTINUAR acontecendo: o Faturar sobre o detalhe que o
// pediu troca para a aba Faturadas página 1, a OS do ato reaberta/a caminho é RELIDA, o plano abre SE E SÓ SE `_showsOrder`.
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R16-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_r16_gate_test.dart
//   - `[FATO R16-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada achado/limite.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail (molde dos gates R9–R15).
//
// RESULTADO (2026-10-13): o PRODUTO resistiu — nenhum ACHADO no bloc (matriz dirigida de 1.248 células com eventos diretos; fuzz de 400
// sequências NOVAS pela página e 300 com atos diretos, mais as 500 sementes do R15, sob oráculos mais fortes: a regra escrita do fim do
// ato num modelo de referência). Os achados são do método: R16-ADV-01 (o Faturar com outro ato da MESMA OS no ar não troca de aba —
// anterior ao delta, família D-F191 (b)/D-F201), R16-ADV-02 (a tolerância do desfecho engolido nos fuzz R14/R15 não confere a causa —
// falso negativo), R16-ADV-03 (o oráculo (7) do R15 reprova por engano a D-F191 (b)/D-F201 por um caminho da página — falso positivo).

//
// DEPOIS DO GATE (correções da sessão, 2026-10-13 — autorização em pé): R16-ADV-01 → D-F203 (conhecimento negativo no `_endDetailAct`);
// R16-ADV-02 → o oráculo (2) do R14 e do R15 só aceita o desfecho engolido no passo de um get/post que FALHOU (com a lista como 1ª emissão);
// R16-ADV-03 → o oráculo (7) do R15 conta como irmão QUALQUER parte da cadeia de outro ato da mesma OS. Os testes de cada achado ficam com os
// predicados de ANTES copiados (a prova do defeito); os gates R14/R15 já rodam com os novos.
import 'dart:async';
import 'dart:convert';
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

/// Os NÚMEROS que a tela mostra PERMUTAM os ids (o número de cada OS é o id de OUTRA) — o molde dos gates R13–R15 (R12-ADV-06).
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
const _refused = Failure(message: 'recusada', statusCode: 422, code: 'R16_REFUSED');
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

/// O fim do ato pela regra ESCRITA do bloc (comentários da D-F182/D-F193/D-F194/D-F199): 'end' = `_endDetailAct` (o detalhe volta sem
/// `saving` só sobre o detalhe DESTA OS, mesma tela capturada); 'reread' = `_rereadAfterAct` (relê se a tela mostra ou vai mostrar a OS);
/// 'plan' = o diálogo SE E SÓ SE `_showsOrder`; 'invoice' = a troca de aba só sobre o detalhe capturado desta OS; 'cancelOs' = a lista só
/// pela tela DELA.
String _endRuleOf(String act, String r) {
  final ok = r == 'ok';
  final unknown = r == 'unknown';
  return switch (act) {
    'transmit' => 'reread',
    'refresh' => ok ? 'reread' : 'end',
    'reconfirm' => ok || unknown ? 'reread' : 'end',
    'xml' || 'danfse' => 'end',
    'plan' => ok ? 'plan' : 'end',
    'localCancel' || 'authCancel' => 'reread',
    'waiver' => ok ? 'reread' : 'end',
    'itemSave' || 'itemRemove' => ok ? 'reread' : 'end',
    'invoice' => ok ? 'invoice' : 'end',
    'cancelOs' => ok ? 'cancelOs' : 'end',
    _ => throw ArgumentError(act),
  };
}

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

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

PagedResult<ServiceOrderListItem> _page(List<int> ids) => PagedResult(items: [
      for (final id in ids) ServiceOrderListItem(id: id, number: _numberOf[id], customerId: 1, status: id == _newId ? 'A' : 'F'),
    ], page: 1, pageSize: 10, total: ids.length);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState? _shownOrNull(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
ServiceOrderState _shown(List<ServiceOrderState> states) => _shownOrNull(states)!;
bool _isScreen(ServiceOrderState s) => s is ServiceOrderListState || s is ServiceOrderDetailState;

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

/// RÉPLICAS literais das tolerâncias do oráculo (2) dos fuzz R14 (apertada pelo R15-SOC-04 (i) — `adversarial_r14_gate_test.dart`, o
/// `if (!stepHadOutcome && stepStartState is ServiceOrderActionFailure && stepEmits == 1)`) e R15 (`adversarial_r15_gate_test.dart`, o
/// `if (!stepHadOutcome && startState != null && _outcome(startState).$1)`) — para medir o que cada uma deixa passar.
bool _r14Tolerates({required bool stepHadOutcome, required ServiceOrderState? stepStartState, required int stepEmits}) =>
    !stepHadOutcome && stepStartState is ServiceOrderActionFailure && stepEmits == 1;
bool _r15Tolerates({required bool stepHadOutcome, required ServiceOrderState? stepStartState}) =>
    !stepHadOutcome && stepStartState != null && _outcome(stepStartState).$1;

/// Um ATO no detalhe do fuzzer: a OS dele, o evento, se nasceu no detalhe ABERTO dela (botões livres), o nº do pedido de tela do operador
/// de então, se nasceu com OUTRO ato da mesma OS no ar, e o `_screenGeneration` que o bloc capturou no começo (modelo de REFERÊNCIA).
class _ActRec {
  _ActRec(this.os, this.event,
      {required this.bornOnOpen, required this.opSeq, required this.siblingInFlight, required this.gen, required this.inFlightAtBegin});
  final int os;
  final ServiceOrderEvent event;
  final bool bornOnOpen;
  final int opSeq;
  final bool siblingInFlight;
  final int gen;

  /// Os atos da MESMA OS com QUALQUER parte da cadeia no ar no começo deste (o decisivo, a releitura, a voz/efeito da releitura) — a
  /// D-F191 (b) por inteiro ("com OUTRO ato em voo na mesma OS, o detalhe relido sai SEM saving"); o `siblingInFlight` do R15 só olha o
  /// decisivo.
  final Set<_ActRec> inFlightAtBegin;
}

/// Uma resposta EM VOO do fuzzer. [finish] recebe a falha (null = ok); [openGen]: o pedido de tela do "Abrir OS" do POST.
class _Flight {
  _Flight(this.label, this.finish, this.tag, this.act, {this.openGen});
  final String label;
  final void Function(Failure? failure) finish;
  final String tag;
  final _ActRec? act;
  final int? openGen;
  int? get os => int.tryParse(label.split(' ').last);
  String get kind => label.split(' ').first;
}

class _Dialog {
  _Dialog(this.decision);
  final ServiceOrderEvent decision;
}

/// As telas do COMEÇO do ato DIRETO (a OS do ato nunca está aberta nelas — é a porta que a página não alcança).
enum _Begin { otherOpen, otherSaving, otherOnTheWay, list, longOpOverOther, ownOnTheWay }

/// O que acontece com a tela ENTRE o começo e o fim do ato.
enum _End { stay, lands, ownOpened, ownOnTheWay, otherOpened, toList }

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;

  /// Cada leitura de uma OS pega o PRÓXIMO futuro da fila (ou a resposta imediata de sempre).
  late Map<int, List<Completer<Either<Failure, ServiceOrderFull>>>> getQueue;
  late Map<int, int> getCalls;
  late int listCalls;

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
    listCalls = 0;
    when(() => repo.getList(any(), any(),
        page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria'))).thenAnswer((_) async {
      listCalls++;
      return Right(_page([_newId, _aId, _bId]));
    });
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

  /// Estaciona a chamada que DECIDE o ato [act] na OS [id] e devolve quem a termina: 'ok', 'refused' (422 com código) ou 'unknown'
  /// (`NetworkFailure` — o desfecho DESCONHECIDO). Molde do gate R15.
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

  // ---------------------------------------------------------------------
  // 1. D-F199 × eventos DIRETOS — a matriz dirigida (a porta que a página não alcança: o ato de uma OS que não é a da tela)
  // ---------------------------------------------------------------------
  group('D-F199 × evento DIRETO — o ato da A com a B aberta / em `saving` / a caminho / a lista / lote por cima / a A a caminho', () {
    test('[RESISTIU] a matriz 13 atos × 6 telas do COMEÇO × 5–6 transições × 3 desfechos (1.248 células): o começo não emite NADA (a OS do '
        'ato não está aberta — nenhum `saving` em outra OS); no fim, com a tela de agora FORA da OS do ato nenhuma emissão de tela (nem o '
        'detalhe da outra OS, nem a lista, nem o plano) e o desfecho com o NÚMERO da OS do ato; com a tela NELA (aberta, reaberta ou a '
        'caminho): só o detalhe dela, a lista só no "Cancelar OS" ok (ou no Faturar sobre o MESMO pedido de tela — a A a caminho que chegou), '
        'a releitura (1 GET) nos atos que mudam a OS, o plano abre e o desfecho sai sem prefixo; a outra OS em `saving` segue em `saving`; '
        'no repouso nada preso', () async {
      final wrong = <String>[];
      final cover = <String, int>{};
      void count(String k) => cover[k] = (cover[k] ?? 0) + 1;
      var cells = 0;
      for (final act in [..._fiscalActs, ..._openActs]) {
        final open = _openActs.contains(act);
        final own = open ? _newId : _aId;
        final other = open ? _aId : _bId;
        for (final begin in _Begin.values) {
          final ends = begin == _Begin.otherOnTheWay || begin == _Begin.ownOnTheWay ? _End.values : _End.values.where((e) => e != _End.lands);
          for (final end in ends) {
            for (final r in _results) {
              final tag = '$act/${begin.name}/${end.name}/$r';
              resetMocks();
              final finish = arm(act, own);
              final (bloc, states, sub) = await start();
              final drains = <void Function()>[];
              Future<void> add(ServiceOrderEvent e) async {
                bloc.add(e);
                await pumpEventQueue(times: 20);
              }

              const list = ServiceOrderListRequested(status: 'A', filter: '');
              await add(list);   // o initState
              Completer<Either<Failure, ServiceOrderFull>>? parked;
              switch (begin) {
                case _Begin.otherOpen:
                  await add(ServiceOrderViewRequested(other));
                case _Begin.otherSaving:
                  final t = arm('transmit', other);
                  drains.add(() => t('ok'));
                  await add(ServiceOrderViewRequested(other));
                  await add(ServiceOrderTransmitRequested(other));
                case _Begin.otherOnTheWay:
                  parked = parkNextGet(other);
                  await add(ServiceOrderViewRequested(other));
                case _Begin.list:
                  break;
                case _Begin.longOpOverOther:
                  await add(ServiceOrderViewRequested(other));
                  final c = Completer<Either<Failure, ServiceOrderTransmitResult>>();
                  when(() => nfse.transmit(other)).thenAnswer((_) => c.future);
                  drains.add(() => c.complete(Right(ServiceOrderTransmitResult(invoiceId: other, attempt: 1, accessKey: 'K'))));
                  await add(ServiceOrderFiscalTransmitBatchRequested([other]));
                case _Begin.ownOnTheWay:
                  parked = parkNextGet(own);
                  await add(ServiceOrderViewRequested(own));
              }
              final p = parked;
              final parkedOrder = _orderOf[begin == _Begin.ownOnTheWay ? own : other]!;
              if (p != null) {
                drains.add(() {
                  if (!p.isCompleted) p.complete(Right(parkedOrder));
                });
              }
              final otherSavingAtBegin = begin == _Begin.otherSaving;
              final beforeAct = states.length;
              await add(_eventOf(act, own));
              if (states.length != beforeAct) wrong.add('$tag: o começo emitiu ${states.sublist(beforeAct)}');
              switch (end) {
                case _End.stay:
                  break;
                case _End.lands:
                  p!.complete(Right(parkedOrder));
                  await pumpEventQueue(times: 20);
                case _End.ownOpened:
                  await add(list);
                  await add(ServiceOrderViewRequested(own));
                case _End.ownOnTheWay:
                  await add(list);
                  final g = parkNextGet(own);
                  drains.add(() {
                    if (!g.isCompleted) g.complete(Right(_orderOf[own]!));
                  });
                  await add(ServiceOrderViewRequested(own));
                case _End.otherOpened:
                  await add(list);
                  await add(ServiceOrderViewRequested(other));
                case _End.toList:
                  await add(list);
              }
              // a tela de AGORA é a da OS do ato? (aberta, reaberta ou a caminho) — e o MESMO pedido de tela do começo (a A a caminho que chegou)
              final ownEnd = end == _End.ownOpened ||
                  end == _End.ownOnTheWay ||
                  (begin == _Begin.ownOnTheWay && (end == _End.stay || end == _End.lands));
              final sameScreenOwnDetail = begin == _Begin.ownOnTheWay && end == _End.lands;
              final otherStillSaving = otherSavingAtBegin && end == _End.stay;
              final rule = _endRuleOf(act, r);
              final getsBefore = getCalls[own] ?? 0;
              final listsBefore = listCalls;
              final at = states.length;
              finish(r);
              await pumpEventQueue(times: 20);
              final step = states.sublist(at);
              final gets = (getCalls[own] ?? 0) - getsBefore;
              final lists = listCalls - listsBefore;
              final outs = step.where((s) => _outcome(s).$1).toList();
              final plans = step.whereType<ServiceOrderCancelPlanReady>().length;
              final screens = step.where(_isScreen).toList();
              final expected = ownEnd ? null : _numberOf[own];
              count(ownEnd ? 'ownEnd' : 'elsewhereEnd');
              if (rule == 'plan') {
                if (plans != (ownEnd ? 1 : 0)) wrong.add('$tag: $plans diálogo(s) do plano (tela da OS do ato: $ownEnd)');
                if (outs.isNotEmpty) wrong.add('$tag: o plano virou desfecho $outs');
              } else if (outs.isEmpty) {
                wrong.add('$tag: nenhum desfecho');
              }
              for (final o in outs) {
                if (_outcome(o).$2 != expected) wrong.add('$tag: ${o.runtimeType} com about=${_outcome(o).$2} (esperado $expected)');
              }
              if (!ownEnd) {
                if (screens.isNotEmpty) wrong.add('$tag: o fim do ato FORA da OS dele mexeu na tela: $screens');
                if (gets != 0 || lists != 0) wrong.add('$tag: fora da OS dele o fim pediu $gets GET / $lists lista');
              } else {
                if (screens.whereType<ServiceOrderDetailState>().any((d) => d.order.id != own)) wrong.add('$tag: detalhe de OUTRA OS: $screens');
                final listOk = r == 'ok' && (act == 'cancelOs' || (act == 'invoice' && sameScreenOwnDetail));
                final listsShown = screens.whereType<ServiceOrderListState>().toList();
                if (listsShown.isNotEmpty && !listOk) wrong.add('$tag: a lista derrubou a OS do ato: $screens');
                if (listOk && (listsShown.isEmpty || lists != 1)) wrong.add('$tag: a lista esperada não veio ($screens, $lists chamadas)');
                if (act == 'invoice' && r == 'ok' && sameScreenOwnDetail) {
                  final first = listsShown.firstOrNull;
                  if (first == null || !first.loading || first.status != 'F' || first.page != 1) {
                    wrong.add('$tag: o Faturar sobre o detalhe capturado não foi à aba Faturadas página 1: $first');
                  }
                  count('invoiceTabSwitch');
                }
                final rereads = rule == 'reread' || (rule == 'invoice' && !sameScreenOwnDetail);
                if (rereads && gets != 1) wrong.add('$tag: a OS do ato na tela não foi RELIDA ($gets GET)');
                if (!rereads && gets != 0) wrong.add('$tag: releitura fora da regra ($gets GET, regra $rule)');
                if (rereads) count('rereadOwn');
              }
              if (otherStillSaving) {
                final shown = _shown(states);
                if (!(shown is ServiceOrderDetailState && shown.order.id == other && shown.saving)) {
                  wrong.add('$tag: a OS $other em saving foi desmarcada pelo fim do ato da $own: $shown');
                }
                count('otherSavingKept');
              }
              for (final d in drains) {
                d();
              }
              await pumpEventQueue(times: 40);
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
      }
      // ignore: avoid_print
      print('cobertura da matriz R16: $cover');
      expect(cells, 13 * (2 * 6 + 4 * 5) * 3);
      expect(wrong, isEmpty, reason: '${wrong.length} célula(s) erradas:\n${wrong.take(10).join('\n')}');
      expect(cover['invoiceTabSwitch'] ?? 0, greaterThan(0), reason: '$cover');
      expect(cover['otherSavingKept'] ?? 0, greaterThan(30), reason: '$cover');
    }, timeout: const Timeout(Duration(minutes: 6)));

    test('[RESISTIU] o "Cancelar OS" da OS nova com a A a caminho no MESMO pedido de tela do começo (a A chega DEPOIS do começo e ANTES do '
        'fim): o fim NÃO recarrega a lista (só a tela DELA — D-F199) e o desfecho leva "OS 8001:"; com a OS nova reaberta no meio, recarrega '
        '(D-F182/D-F191)', () async {
      for (final reopen in [false, true]) {
        resetMocks();
        final finish = arm('cancelOs', _newId);
        final (bloc, states, sub) = await start();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 20);
        final g = parkNextGet(_aId);
        bloc.add(const ServiceOrderViewRequested(_aId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderCancelRequested(_newId));                               // direto: a OS nova não está na tela
        await pumpEventQueue(times: 20);
        g.complete(const Right(_a));                                                      // a A chega no MESMO pedido de tela
        await pumpEventQueue(times: 20);
        if (reopen) {
          bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
          await pumpEventQueue(times: 20);
          bloc.add(const ServiceOrderViewRequested(_newId));
          await pumpEventQueue(times: 20);
        }
        final at = states.length;
        final lists = listCalls;
        finish('ok');
        await pumpEventQueue(times: 20);
        final step = states.sublist(at);
        await sub.cancel();
        await bloc.close();
        final success = step.whereType<ServiceOrderActionSuccess>().single;
        expect([success.orderNumber, listCalls - lists, step.whereType<ServiceOrderListState>().isNotEmpty],
            reopen ? [null, 1, true] : [_numberOf[_newId], 0, false], reason: 'reopen=$reopen');
      }
    });

    test('[RESISTIU] o Faturar da OS nova pedido com ela A CAMINHO (evento direto) e que termina depois de ela CHEGAR no mesmo pedido de '
        'tela: o bloc trata como "a tela capturada é o detalhe DESTA OS" (`_stillOnActDetail` — o mesmo `_screenGeneration`, o `_detail` é '
        'ela) e vai à aba Faturadas página 1; se ela ainda está a caminho no fim, RELÊ (o pedido "a caminho" renovado — D-F191)', () async {
      for (final landed in [true, false]) {
        resetMocks();
        final finish = arm('invoice', _newId);
        final (bloc, states, sub) = await start();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 20);
        final g = parkNextGet(_newId);
        bloc.add(const ServiceOrderViewRequested(_newId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderInvoiceRequested(orderId: _newId, input: _input));
        await pumpEventQueue(times: 20);
        if (landed) {
          g.complete(const Right(_newOrder));
          await pumpEventQueue(times: 20);
        }
        final at = states.length;
        final gets = getCalls[_newId] ?? 0;
        finish('ok');
        await pumpEventQueue(times: 20);
        final lists = states.sublist(at).whereType<ServiceOrderListState>().toList();
        if (!g.isCompleted) g.complete(const Right(_newOrder));
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        if (landed) {
          expect([lists.first.status, lists.first.page, lists.first.loading, (getCalls[_newId] ?? 0) - gets], ['F', 1, true, 0]);
        } else {
          expect([lists, (getCalls[_newId] ?? 0) - gets], [isEmpty, 1]);
          expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
        }
      }
    });
  });

  // ---------------------------------------------------------------------
  // 2. O Faturar com OUTRO ato da MESMA OS no ar (a família da D-F191 (b)/D-F201) — o que a página alcança
  // ---------------------------------------------------------------------
  group('Faturar × outro ato da MESMA OS no ar (a família da D-F191 (b)/D-F201)', () {
    test('[DECIDIDO D-F203 — era o FATO R16-ADV-01] pela PÁGINA: OS nova aberta → "Salvar item" (`saving`) → a página recriada → a OS reaberta (sem `saving` — '
        'D-F191 (b)) → "Faturar" (`saving`) → o item termina ok e RELÊ (o `_screenGeneration` sobe — "a releitura é um PEDIDO NOVO") → o '
        'Faturar termina ok com o operador NO detalhe dessa OS o tempo todo: NÃO vai à aba Faturadas — relê a OS e fica no detalhe (agora '
        'faturada); voltar à lista mostra a aba Abertas. Anterior ao delta (`_stillOnDetail(screen)` já comparava a tela capturada) e da '
        'raiz já aceita (sem contador de atos POR OS — D-F201); o servidor e a tela relida mostram a verdade', () async {
      for (final rereadLanded in [false, true]) {
        resetMocks();
        final itemDone = arm('itemSave', _newId);
        final invoiceDone = arm('invoice', _newId);
        final (bloc, states, sub) = await start();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderViewRequested(_newId));
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderItemSaveRequested(orderId: _newId, input: _item));     // ato 1 (diálogo do item)
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));              // a página recriada (cruzar 1100 px)
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderViewRequested(_newId));                               // reaberta, sem saving (D-F191 (b))
        await pumpEventQueue(times: 20);
        expect((_shown(states) as ServiceOrderDetailState).saving, isFalse);
        bloc.add(const ServiceOrderInvoiceRequested(orderId: _newId, input: _input));    // ato 2: Faturar
        await pumpEventQueue(times: 20);
        expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
        final reread = rereadLanded ? null : parkNextGet(_newId);
        itemDone('ok');                                                                  // ato 1 termina: relê (o contador sobe)
        await pumpEventQueue(times: 20);
        final at = states.length;
        invoiceDone('ok');                                                               // o Faturar termina
        await pumpEventQueue(times: 20);
        final step = states.sublist(at);
        reread?.complete(const Right(_newOrder));
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        expect(step.whereType<ServiceOrderActionSuccess>().single.orderNumber, isNull, reason: 'a tela é a OS do ato');
        expect([step.whereType<ServiceOrderListState>().length, (_shown(states) as ServiceOrderDetailState).order.id], [0, _newId],
            reason: 'rereadLanded=$rereadLanded: hoje fica no detalhe (relido), sem a troca de aba');
      }
    });
  });

  // ---------------------------------------------------------------------
  // 3. Fuzz — o molde R15 com sementes NOVAS + o modelo de REFERÊNCIA da regra escrita do fim do ato (D-F199)
  // ---------------------------------------------------------------------

  /// O fuzz do gate R15 (o modelo do último pedido de tela do operador; oráculos (1) detalhe só do pedido, (2) lista sobre o detalhe só com
  /// desfecho, (3) plano SE E SÓ SE a tela é a OS dele, (4) prefixo do desfecho, (5) repouso = o último pedido, (6)/(7) `saving` por OS) com:
  ///   - (2) com a tolerância do desfecho ENGOLIDO (D-F198) presa à CAUSA — só o GET/POST que FALHOU (os únicos fins que emitem a falha e
  ///     logo a lista); e o que as tolerâncias literais do R14 e do R15 aceitariam fora dessa causa é CONTADO;
  ///   - (S1) o fim (e a cadeia) de um ato da OS X nunca emite tela com o operador em OUTRA OS (aberta, a caminho ou abrindo);
  ///   - (R) um modelo de REFERÊNCIA do bloc (o `_screenGeneration` pelas chamadas — lista, ver/abrir, releitura —, a marca "a caminho" e a
  ///     OS dela, o `_detail` pelas emissões) que reproduz `_showsOrder` e `_stillOnActDetail`; conferido contra o modelo do OPERADOR a
  ///     cada fim de ato; e o fim de cada ato pela regra ESCRITA: 'end' (detalhe sem `saving` SE E SÓ SE a tela capturada é o detalhe
  ///     desta OS), 'reread' (1 GET SE E SÓ SE `_showsOrder`), 'plan', 'invoice' (aba Faturadas página 1 SE E SÓ SE `_stillOnActDetail`;
  ///     senão releitura pelo `_showsOrder`), 'cancelOs' (a lista SE E SÓ SE `_showsOrder`), saga que continua = nada.
  /// [seedOf]: a semente do `Random` de cada sequência; [inAirNew]: o gerador também reabre a OS NOVA com um ato dela no ar (sementes novas).
  /// [firstSeed]: a 1ª sequência (para reproduzir UMA); [r15Oracle7]: o oráculo (7) LITERAL do R15 (sem as classificações R16-ADV-03).
  Future<Map<String, int>> fuzz(
      {required bool direct,
      required int seeds,
      required int Function(int seed) seedOf,
      required String label,
      bool inAirNew = false,
      int firstSeed = 1,
      bool r15Oracle7 = false}) async {
    final cover = <String, int>{};
    void count(String k) => cover[k] = (cover[k] ?? 0) + 1;
    const actKinds = {'transmit', 'refresh', 'reconfirm', 'xml', 'danfse', 'plan', 'nfsecancel', 'localcancel', 'waiver', 'item', 'itemrm',
        'invoice', 'cancelOs'};
    const chainKinds = {'get', 'voice', 'effect', 'list'};
    const longOps = {ServiceOrderFiscalTransmitBatchRequested, ServiceOrderBatchInvoiceRequested, ServiceOrderMonthlyRunRequested,
        ServiceOrderFiscalPendingRequested};
    for (var seed = firstSeed; seed < firstSeed + seeds; seed++) {
      final rnd = Random(seedOf(seed));
      final flights = <_Flight>[];
      final trace = <String>[];
      final seen = <int>{};
      final states = <ServiceOrderState>[];
      // o MODELO do último pedido de tela do operador
      var last = 'list'; // list | longOp | view | open | detail
      int? os;
      var openSeq = 0;
      var opSeq = 0;
      // o modelo de REFERÊNCIA do bloc
      var gen = 0;
      int? pendingScreen;
      int? pendingOrder;
      final getCallsOf = <int, int>{};
      var listCallsN = 0;
      // o passo corrente
      var stepKind = 'add';
      ServiceOrderEvent? stepEvent;
      _Flight? stepFlight;
      _ActRec? stepAct;
      var stepHadOutcome = false;
      ServiceOrderState? stepStartState;
      var stepPlanShown = false;
      var stepEmits = 0;
      var stepModelLast = 'list';
      int? stepModelOs;
      Failure? stepFailure;
      final violations = <String>[];
      String why() => '$label seed $seed (direct=$direct)\n${trace.join('\n')}';
      _ActRec? actNow() => stepKind == 'add' ? stepAct : stepFlight?.act;
      int? detailNow() {
        final s = _shownOrNull(states);
        return s is ServiceOrderDetailState ? s.order.id : null;
      }

      bool showsRef(int x) => pendingScreen != null && pendingScreen == gen ? pendingOrder == x : detailNow() == x;
      bool modelOwn(int x) => (last == 'view' || last == 'detail' || last == 'open') && os == x;
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
      Future<Either<Failure, T>> park<T>(String label, T Function() ok, {int? openGen}) {
        final c = Completer<Either<Failure, T>>();
        flights.add(_Flight(label, (failure) => c.complete(failure == null ? Right(ok()) : Left(failure)), tagNow(), actNow(), openGen: openGen));
        return c.future;
      }

      repo = ServiceOrderRepoMock();
      nfse = NfseRepoMock();
      invoice = InvoiceRepoMock();
      when(() => repo.getList(any(), any(),
          page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria'))).thenAnswer((_) {
        gen++;   // `_reloadList`: `++_screenGeneration` e logo o getlist
        listCallsN++;
        return park('list', () => _page([_newId, _aId, _bId]));
      });
      for (final id in _orderOf.keys) {
        when(() => repo.getById(id)).thenAnswer((_) {
          getCallsOf[id] = (getCallsOf[id] ?? 0) + 1;
          if (actNow() != null) {
            // a releitura de um ato (`_rereadAfterAct`): o contador sobe ANTES do GET; com a OS a caminho, a marca vai junto (D-F191)
            final onTheWay = pendingScreen != null && pendingScreen == gen;
            gen++;
            if (onTheWay) {
              pendingScreen = gen;
              pendingOrder = id;
            }
            count('ref reread');
          }
          return park('get $id', () => _orderOf[id]!);
        });
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
      when(() => repo.open(5)).thenAnswer((_) => park('post', () => _newId, openGen: gen));
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
      bool onWay() => last == 'view' || last == 'open';
      final sub = bloc.stream.listen((s) {
        states.add(s);
        stepEmits++;
        if (s is ServiceOrderListState) seen.addAll(s.items.map((i) => i.id));
        if (s is ServiceOrderDetailState) {
          seen.add(s.order.id);
          // referência: o detalhe só é emitido com a marca "a caminho" morta (R10-SOC-01: ela morre JUNTO com o `_detail`)
          if (pendingScreen != null && pendingScreen == gen) pendingScreen = null;
        }
        final (isOutcome, about) = _outcome(s);
        final f = stepFlight;
        if (isOutcome) {
          stepHadOutcome = true;
          if (stepKind == 'complete' && f != null && actKinds.contains(f.kind) && f.act != null) {
            final own = (last == 'view' || last == 'detail' || last == 'open') && os == f.os;
            count(own ? 'outcomeOnOwn' : 'outcomeElsewhere');
            if (about != (own ? null : _numberOf[f.os])) violations.add('(4) desfecho de ${f.label} com about=$about (modelo $last $os) — ${why()}');
          }
        }
        if (s is ServiceOrderCancelPlanReady) stepPlanShown = true;
        // (S1) a cadeia do ato da OS X nunca emite TELA com o operador em OUTRA OS (aberta, a caminho ou abrindo)
        final a = f?.act;
        if (stepKind == 'complete' && a != null && _isScreen(s) &&
            (stepModelLast == 'view' || stepModelLast == 'detail' || stepModelLast == 'open') && stepModelOs != a.os) {
          violations.add('(S1) ${s.runtimeType} emitido pelo fim de ${f!.label} (ato da OS ${a.os}) com o operador em $stepModelLast $stepModelOs — ${why()}');
        }
        if (s is ServiceOrderDetailState) {
          final id = s.order.id;
          final act = actNow();
          if (s.saving && !(stepKind == 'add' && act != null && act.os == id)) {
            violations.add('(6) detalhe $id com saving:true fora do começo de um ato DELE (passo $stepKind, ato da OS ${act?.os}) — ${why()}');
          }
          if (!s.saving) {
            final live = flights
                .where((x) => actKinds.contains(x.kind) && x.act != null && x.act != act && x.act!.os == id && x.act!.bornOnOpen && x.act!.opSeq == opSeq)
                .toList();
            if (live.isNotEmpty) {
              if (act != null && act.os == id && act.opSeq < live.first.act!.opSeq) {
                count('D-F191b savingCleared');
              } else if (act != null && act.os == id && live.every((x) => x.act!.siblingInFlight)) {
                count('D-F201 cascadeSavingCleared');
              } else if (!r15Oracle7 && act != null && act.os == id && live.every((x) => x.act!.inFlightAtBegin.contains(act))) {
                // R16-ADV-03: a D-F191 (b) pelo MESMO pedido de tela — o ato que relê nasceu com a OS a caminho (D-F197) e a releitura dele
                // (a voz/efeito no ar) ainda corria quando o ato vivo começou; o oráculo (7) do R15 reprovaria (opSeq igual, decisivo já fora)
                count('R16-ADV-03 D-F191b sameScreenSiblingReread');
              } else if (!r15Oracle7 && act != null && act.os == id && live.every((x) => x.act!.inFlightAtBegin.isNotEmpty)) {
                // R16-ADV-03: a CASCATA da D-F201 com o irmão só na RELEITURA — o ato vivo nasceu com a cadeia de outro ato da mesma OS no ar
                // (botões reabertos por ela); o fim de um 3º o desmarca. O `siblingInFlight` do R15 (só o decisivo) não vê
                count('R16-ADV-03 D-F201 cascadeSiblingInReread');
              } else if (direct && act != null && act.os == id) {
                count('sameOsSecondAct savingCleared');
              } else {
                violations.add('(7) detalhe $id sem saving com o ato ${live.first.label} DELE no ar (passo $stepKind, ato da OS ${act?.os} '
                    '${act?.event.runtimeType} opSeq ${act?.opSeq}; vivos: ${live.map((x) => '${x.label} opSeq ${x.act!.opSeq} '
                    'inFlightAtBegin ${x.act!.inFlightAtBegin.map((y) => '${y.event.runtimeType}/${identical(y, act)}').toList()}').toList()}) — ${why()}');
              }
            }
          }
          if (!((last == 'view' || last == 'open' || last == 'detail') && os == id)) {
            violations.add('(1) detalhe $id emitido com o modelo em $last $os — ${why()}');
          } else if (onWay()) {
            last = 'detail';
          }
        } else if (s is ServiceOrderListState) {
          if (stepKind == 'complete') {
            if (onWay() || last == 'detail') {
              final startState = stepStartState;
              final cause = f != null && (f.kind == 'get' || f.kind == 'post') && stepFailure != null;
              if (!stepHadOutcome) {
                // as tolerâncias LITERAIS dos fuzz R14/R15 — o que cada uma aceitaria aqui, com e sem a causa
                final r14 = _r14Tolerates(stepHadOutcome: stepHadOutcome, stepStartState: startState, stepEmits: stepEmits);
                final r15 = _r15Tolerates(stepHadOutcome: stepHadOutcome, stepStartState: startState);
                if (r14) count(cause ? 'R14 tolerance (get/post FAIL)' : 'R14 tolerance OUTRA causa');
                if (r15) count(cause ? 'R15 tolerance (get/post FAIL)' : 'R15 tolerance OUTRA causa');
                if (cause && stepEmits == 1 && startState is ServiceOrderActionFailure) {
                  count('D-F198 outcomeSwallowed (get/post FAIL)');
                } else {
                  violations.add('(2) lista emitida com o modelo em $last $os, sem desfecho no passo (${f?.label}) — ${why()}');
                }
              }
              last = 'list';
              os = null;
            }
          } else if (stepEvent != null && longOps.contains(stepEvent.runtimeType) && last == 'detail') {
            last = 'longOp';
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
          if (!bloc.isClosed) {
            gen++;   // `_showListLoading(emit)` — e a marca "a caminho" (D-F191)
            pendingScreen = gen;
            pendingOrder = e.id;
          }
        } else if (e is ServiceOrderOpenRequested) {
          last = 'open';
          os = null;
          openSeq++;
          opSeq++;
          if (!bloc.isClosed) {
            gen++;
            pendingScreen = gen;
            pendingOrder = null;   // a OS ainda não existe (o POST dá o id)
          }
        }
        final before = _shownOrNull(states);
        final actOs = _actOsOf(e);
        stepAct = actOs == null
            ? null
            : _ActRec(actOs, e,
                bornOnOpen: last == 'detail' && os == actOs && before is ServiceOrderDetailState && before.order.id == actOs && !before.saving,
                opSeq: opSeq,
                siblingInFlight: flights.any((x) => actKinds.contains(x.kind) && x.act != null && x.act!.os == actOs),
                gen: gen,
                inFlightAtBegin: {
                  for (final x in flights)
                    if (x.act != null && x.act!.os == actOs) x.act!,
                });
        if (actOs != null && before is ServiceOrderDetailState && before.order.id != actOs) count('beginOnOtherDetail');
        stepKind = 'add';
        stepEvent = e;
        stepFlight = null;
        stepHadOutcome = false;
        stepPlanShown = false;
        stepEmits = 0;
        stepFailure = null;
        stepModelLast = last;
        stepModelOs = os;
        stepStartState = states.lastOrNull;
        if (!bloc.isClosed) bloc.add(e);
        await pumpEventQueue();
      }

      Future<void> completeOne({double okRate = 0.75}) async {
        var i = rnd.nextInt(flights.length);
        for (var retry = 0; retry < 2 && actKinds.contains(flights[i].kind) && flights.length > 1; retry++) {
          i = rnd.nextInt(flights.length);
        }
        final planOfTheWay = flights.indexWhere((x) => x.kind == 'plan' && x.tag == 'flow' && last == 'view' && x.os == os);
        if (planOfTheWay >= 0 && rnd.nextBool()) i = planOfTheWay;
        final f = flights.removeAt(i);
        final ok = rnd.nextDouble() < okRate;
        final planOwn = (last == 'view' || last == 'detail') && os == f.os;
        if (f.kind == 'post' && ok && last == 'open' && f.tag == 'open$openSeq') os = _newId;
        // referência: o POST que volta dá o id à marca "a caminho" DELE (`if (_pendingDetailScreen == screen) _pendingDetailOrder = id`)
        if (f.kind == 'post' && ok && pendingScreen != null && pendingScreen == f.openGen) pendingOrder = _newId;
        final at = states.length;
        trace.add('<- ${f.label}${f.tag.isEmpty ? '' : ' [${f.tag}]'} ${ok ? 'ok' : 'FAIL'}');
        // o fim do ato pela regra ESCRITA — as premissas lidas ANTES de o bloc retomar
        final a = f.act;
        final decisive = a != null && !chainKinds.contains(f.kind) && actKinds.contains(f.kind);
        var refOwn = false;
        var refStill = false;
        if (a != null && decisive) {
          refOwn = showsRef(a.os);
          refStill = a.gen == gen && detailNow() == a.os;
          if (refOwn != modelOwn(a.os)) {
            violations.add('(R) referência ($refOwn) × operador (${modelOwn(a.os)}) divergem no fim de ${f.label} — ${why()}');
          }
          final shownId = detailNow();
          if (a.gen == gen && shownId != null && shownId != a.os) count('endSameScreenOtherDetail');   // onde a regra antiga e a D-F199 divergem
        }
        final getsBefore = Map.of(getCallsOf);
        final listsBefore = listCallsN;
        stepKind = 'complete';
        stepEvent = null;
        stepFlight = f;
        stepAct = null;
        stepHadOutcome = false;
        stepPlanShown = false;
        stepEmits = 0;
        stepModelLast = last;
        stepModelOs = os;
        stepStartState = states.lastOrNull;
        final failure = ok ? null : fail();
        stepFailure = failure;
        f.finish(failure);
        await pumpEventQueue();
        if (actKinds.contains(f.kind) && f.act != null) count('done ${f.kind}');
        if (a != null && decisive) {
          final n = a.os;
          final step = states.sublist(at);
          final screens = step.where(_isScreen).toList();
          final gets = (getCallsOf[n] ?? 0) - (getsBefore[n] ?? 0);
          final lists = listCallsN - listsBefore;
          final ev = a.event;
          final continued = ev is ServiceOrderCancelConfirmed &&
              flights.any((x) => identical(x.act, a) && (x.kind == 'nfsecancel' || x.kind == 'localcancel'));
          final unknown = failure != null && isUnknownAuthorityOutcome(failure);
          final rule = switch (ev) {
            ServiceOrderTransmitRequested() => 'reread',
            ServiceOrderFiscalRefreshRequested() => ok ? 'reread' : 'end',
            ServiceOrderFiscalReconfirmRequested() => ok || unknown ? 'reread' : 'end',
            ServiceOrderFiscalXmlRequested() || ServiceOrderFiscalDanfseRequested() => 'end',
            ServiceOrderCancelFlowRequested() => ok ? 'plan' : 'end',
            ServiceOrderCancelConfirmed() => continued ? 'none' : 'reread',
            ServiceOrderFiscalCancelWaiverRequested() => ok || failure?.code == FiscalCodes.cancelWaiverNotApplicable ? 'reread' : 'end',
            ServiceOrderItemSaveRequested() || ServiceOrderItemRemoveRequested() => ok ? 'reread' : 'end',
            ServiceOrderInvoiceRequested() => ok ? 'invoice' : 'end',
            ServiceOrderCancelRequested() => ok ? 'cancelOs' : 'end',
            _ => 'other',
          };
          String? bad;
          switch (rule) {
            case 'none':
              if (screens.isNotEmpty || gets != 0 || lists != 0) bad = 'a saga segue e mexeu: $screens, $gets GET, $lists lista';
            case 'end':
              final ok1 = refStill
                  ? screens.length == 1 && screens.single is ServiceOrderDetailState &&
                      (screens.single as ServiceOrderDetailState).order.id == n && !(screens.single as ServiceOrderDetailState).saving
                  : screens.isEmpty;
              if (!ok1 || gets != 0 || lists != 0) bad = 'end (still=$refStill): $screens, $gets GET, $lists lista';
            case 'reread':
              if (screens.isNotEmpty || gets != (refOwn ? 1 : 0) || lists != 0) bad = 'reread (own=$refOwn): $screens, $gets GET, $lists lista';
            case 'plan':
              // o plano não tem desfecho antes do `_endDetailAct`: o detalhe re-emitido IGUAL ao estado atual (a OS já sem `saving` — D-F197/
              // D-F201) é engolido pelo bloc (D-F198)
              final start = stepStartState;
              final detailSwallowed = start is ServiceOrderDetailState && start.order.id == n && !start.saving;
              if (refOwn && refStill && detailSwallowed && screens.isEmpty) count('D-F198 planEndDetailSwallowed');
              final ok1 = refOwn && refStill
                  ? (screens.length == 1 && screens.single is ServiceOrderDetailState && (screens.single as ServiceOrderDetailState).order.id == n) ||
                      (detailSwallowed && screens.isEmpty)
                  : screens.isEmpty;
              final swallowed = !stepPlanShown && refOwn && !refStill && stepStartState is ServiceOrderCancelPlanReady;
              if (!ok1 || gets != 0 || lists != 0 || (stepPlanShown != refOwn && !swallowed)) {
                bad = 'plan (own=$refOwn, still=$refStill): $screens, plano ${stepPlanShown ? 'aberto' : 'não'}';
              }
              count(refOwn ? 'E plan own' : 'E plan elsewhere');
            case 'invoice':
              if (refStill) {
                final first = screens.firstOrNull;
                if (first is! ServiceOrderListState || !first.loading || first.status != 'F' || first.page != 1 || lists != 1 || gets != 0) {
                  bad = 'Faturar sobre o detalhe capturado sem a aba Faturadas página 1: $screens, $gets GET, $lists lista';
                }
                count('E invoice tabSwitch');
              } else if (refOwn) {
                if (screens.isNotEmpty || gets != 1 || lists != 0) bad = 'Faturar com a OS reaberta/a caminho sem releitura: $screens, $gets GET, $lists lista';
                count('E invoice reread');
              } else {
                if (screens.isNotEmpty || gets != 0 || lists != 0) bad = 'Faturar fora da OS mexeu: $screens, $gets GET, $lists lista';
                count('E invoice elsewhere');
              }
            case 'cancelOs':
              final ok1 = refOwn
                  ? screens.firstOrNull is ServiceOrderListState && (screens.first as ServiceOrderListState).loading && lists == 1
                  : screens.isEmpty && lists == 0;
              if (!ok1 || gets != 0) bad = 'Cancelar OS (own=$refOwn): $screens, $gets GET, $lists lista';
              count(refOwn ? 'E cancelOs list' : 'E cancelOs elsewhere');
          }
          if (rule == 'end') count(refStill ? 'E end still' : 'E end notStill');
          if (rule == 'reread') count(refOwn ? 'E reread own' : 'E reread elsewhere');
          if (bad != null) violations.add('(E) fim de ${f.label} [${ev.runtimeType}, regra $rule]: $bad — ${why()}');
        }
        // (3) o 1º passo do cancelamento: o diálogo SE E SÓ SE o modelo é a OS dele (aberta ou a caminho) — do R15
        if (f.kind == 'plan' && f.tag == 'flow' && ok) {
          count(planOwn ? 'planOnOwn' : 'planElsewhere');
          if (stepPlanShown && !planOwn) {
            violations.add('(3) plano de ${f.os} abriu com o modelo em $last $os — ${why()}');
          } else if (!stepPlanShown && planOwn) {
            final startState = stepStartState;
            if (startState is ServiceOrderCancelPlanReady && startState.plan.orderId == f.os) {
              count('D-F198 planSwallowed');
            } else {
              violations.add('(3) plano de ${f.os} NÃO abriu com o modelo nele ($last $os) — ${why()}');
            }
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
        if (direct && rnd.nextDouble() < 0.3) {
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
              dialog = _Dialog(const ServiceOrderOpenRequested(5));
            }
          } else if (pick < 60) {
            final planInAir = flights.where((f) => f.kind == 'plan' && f.tag == 'flow').map((f) => f.os!).toList();
            final inAir = planInAir.isNotEmpty && rnd.nextInt(4) > 0
                ? planInAir
                : flights
                    .where((f) => actKinds.contains(f.kind) && (f.os == _aId || f.os == _bId || (inAirNew && f.os == _newId)))
                    .map((f) => f.os!)
                    .toList();
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
      if (violations.isNotEmpty) count('seedsWithViolation');
      expect(violations, isEmpty, reason: violations.isEmpty ? '' : violations.first);
    }
    return cover;
  }

  group('fuzz do bloc R16 — sementes NOVAS + a regra escrita do fim do ato (D-F199) num modelo de referência', () {
    const minimumPage = {'outcomeOnOwn': 300, 'outcomeElsewhere': 100, 'recreatedUnderDialog': 100, 'planOnOwn': 20, 'planElsewhere': 5,
        'E end still': 100, 'E end notStill': 50, 'E reread own': 100, 'E reread elsewhere': 30, 'E invoice tabSwitch': 20,
        'E invoice reread': 2, 'E cancelOs list': 20, 'E cancelOs elsewhere': 5, 'E plan own': 20};

    test('[RESISTIU] 400 sequências NOVAS pelo que a PÁGINA despacha (o gerador do R15 + a OS nova reaberta com ato dela no ar): os '
        'oráculos (1)–(7) do R15, (2) com a tolerância presa à causa (GET/POST que falhou), (S1) a cadeia de um ato nunca emite tela com o '
        'operador em OUTRA OS, (R) o modelo de referência concorda com o do operador em todo fim de ato, e (E) cada fim pela regra escrita — '
        'o Faturar sobre o detalhe capturado vai à aba Faturadas página 1, a OS reaberta/a caminho é RELIDA, o plano abre SE E SÓ SE '
        '`_showsOrder`, o "Cancelar OS" recarrega a lista só pela tela DELA; e o diferencial da D-F199 (`endSameScreenOtherDetail` — o fim '
        'com o MESMO pedido de tela e OUTRA OS no detalhe, onde a regra antiga re-emitia/trocava de aba/abria o plano) = 0: latente', () async {
      final cover = await fuzz(direct: false, seeds: 400, seedOf: (s) => s * 7919 + 1601, label: 'R16 página', inAirNew: true);
      // ignore: avoid_print
      print('cobertura do fuzz R16 (página, sementes novas): $cover');
      expect([cover['beginOnOtherDetail'] ?? 0, cover['endSameScreenOtherDetail'] ?? 0], [0, 0], reason: 'D-F199 latente: $cover');
      for (final e in minimumPage.entries) {
        expect(cover[e.key] ?? 0, greaterThan(e.value), reason: 'o fuzz quase não exercitou "${e.key}": $cover');
      }
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('[RESISTIU] 300 sequências NOVAS com atos DIRETOS (qualquer OS, qualquer tela): os mesmos oráculos — e o diferencial da D-F199 '
        'EXERCITADO (`endSameScreenOtherDetail` > 0: o fim do ato da A com a B no detalhe do MESMO pedido de tela — onde a regra antiga '
        'devolvia a B sem `saving`, trocava de aba ou abria o plano da A sobre a B); nenhuma violação de (E)/(S1)', () async {
      final cover = await fuzz(direct: true, seeds: 300, seedOf: (s) => s * 32452843 + 104729, label: 'R16 direto', inAirNew: true);
      // ignore: avoid_print
      print('cobertura do fuzz R16 (eventos diretos, sementes novas): $cover');
      expect(cover['directAct'] ?? 0, greaterThan(1500));
      for (final k in const ['beginOnOtherDetail', 'endSameScreenOtherDetail']) {
        expect(cover[k] ?? 0, greaterThan(30), reason: '$k: $cover');
      }
      for (final k in const ['E invoice tabSwitch', 'E invoice reread', 'E plan own', 'E end still', 'E reread own']) {
        expect(cover[k] ?? 0, greaterThan(5), reason: '$k: $cover');
      }
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('[RESISTIU] as MESMAS sementes do gate R15 (300 página + 200 diretos, o gerador idêntico) sob os oráculos MAIS FORTES deste gate — '
        '(2) com a tolerância presa à causa, (S1), (R) e (E): nada que o R15 deixou passar com a tolerância solta', () async {
      final page = await fuzz(direct: false, seeds: 300, seedOf: (s) => s * 104723, label: 'R15 página');
      final direct = await fuzz(direct: true, seeds: 200, seedOf: (s) => s * 15485863, label: 'R15 direto');
      // ignore: avoid_print
      print('cobertura R16 sobre as sementes R15 — página: $page\ndiretos: $direct');
      expect(page['endSameScreenOtherDetail'] ?? 0, 0, reason: '$page');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  // ---------------------------------------------------------------------
  // 4. Os oráculos apertados dos gates R13/R14 (R15-SOC-04) — o que eles deixam passar
  // ---------------------------------------------------------------------
  group('R15-SOC-04 — os oráculos dos fuzz R14/R15 × um falso NEGATIVO (R16-ADV-02) e um falso POSITIVO (R16-ADV-03)', () {
    test('[CORRIGIDO no R14/R15 — o FATO R16-ADV-02 de ANTES, com os predicados de então copiados aqui] a tolerância do desfecho ENGOLIDO no oráculo (2) — no R14 (apertada: a lista é a 1ª emissão, o estado do começo é '
        'uma `ActionFailure`) e no R15 (solta: qualquer desfecho, qualquer posição) — não confere a CAUSA (o fim que emite a falha e logo a '
        'lista: o GET/POST que falhou). A PÁGINA alcança a pré-condição: a OS A com um "Consultar" no ar, a página recriada (a recarga da '
        'lista fica NO AR), a OS B aberta, o "Consultar" da A recusado → o último estado é a `ActionFailure` "OS 77:" com a B na tela; a '
        'recarga velha da lista chega — o bloc a descarta (R7-SOC-03/D-F174: RESISTIU), mas uma regressão que a deixasse emitir (a lista '
        'velha POR CIMA da B, 1ª emissão do passo, sem desfecho) seria ACEITA pelas duas tolerâncias como "desfecho engolido" — o falso '
        'negativo que o aperto da R15-SOC-04 (i) não fechou', () async {
      final refreshA = arm('refresh', _aId);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));                            // ato da A no ar
      await pumpEventQueue(times: 20);
      final staleList = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) => staleList.future);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada — a lista fica no ar
      await pumpEventQueue(times: 20);
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => Right(_page([_newId, _aId, _bId])));
      bloc.add(const ServiceOrderViewRequested(_bId));                                   // a B aberta
      await pumpEventQueue(times: 20);
      refreshA('refused');                                                               // o ato da A termina FORA da OS dela
      await pumpEventQueue(times: 20);
      final startState = states.last;                                                    // o estado do começo do próximo passo
      final shownB = _shown(states) as ServiceOrderDetailState;
      final at = states.length;
      staleList.complete(Right(_page([_newId, _aId, _bId])));                             // a recarga VELHA chega
      await pumpEventQueue(times: 20);
      final step = states.sublist(at);
      await sub.cancel();
      await bloc.close();
      // a pré-condição alcançada pela página
      expect([startState is ServiceOrderActionFailure, (startState as ServiceOrderActionFailure).orderNumber, shownB.order.id],
          [true, _numberOf[_aId], _bId]);
      // o produto RESISTIU: a lista velha não emitiu
      expect(step, isEmpty);
      // as duas tolerâncias aceitariam a regressão (a lista velha como 1ª emissão do passo, sem desfecho)
      expect(_r14Tolerates(stepHadOutcome: false, stepStartState: startState, stepEmits: 1), isTrue);
      expect(_r15Tolerates(stepHadOutcome: false, stepStartState: startState), isTrue);
    });

    test('[CORRIGIDO no R15 — o FATO R16-ADV-03 de ANTES, com o oráculo de então copiado aqui] o oráculo (7) do fuzz R15 REPROVA POR ENGANO a D-F191 (b)/D-F201 aceitas por um caminho da PÁGINA que as '
        'sementes fixas do R15 não sorteiam: com o MESMO gerador, a sequência 152 das sementes novas deste gate (página, sem evento direto) '
        'reprova sob o oráculo (7) LITERAL do R15 — o ato que reabre os botões é a SAGA nascida com a OS a caminho (D-F197, a porta da '
        'D-F194), a releitura dela (só a voz/efeito no ar — o `siblingInFlight` do R15 olha só a chamada decisiva) corre quando o operador '
        'clica "Transmitir", e a releitura chega com o Transmitir no ar (opSeq IGUAL — a exceção "ato ANTIGO" do R15 exige menor). Sob as '
        'classificações deste gate (`inFlightAtBegin`: qualquer parte da cadeia de outro ato da mesma OS) a mesma sequência passa', () async {
      int seedOf(int s) => s * 7919 + 1601;
      await expectLater(
          fuzz(direct: false, seeds: 1, firstSeed: 152, seedOf: seedOf, label: 'R15 (7) literal', inAirNew: true, r15Oracle7: true),
          throwsA(isA<TestFailure>().having((e) => e.message, 'message', contains('(7) detalhe 8001 sem saving com o ato transmit 8001'))));
      final cover = await fuzz(direct: false, seeds: 1, firstSeed: 152, seedOf: seedOf, label: 'R16 (7)', inAirNew: true);
      expect(cover['R16-ADV-03 D-F191b sameScreenSiblingReread'] ?? 0, greaterThan(0), reason: '$cover');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('[CORRIGIDO no R15 — o FATO R16-ADV-03 de ANTES, com o oráculo de então copiado aqui] o caminho DIRIGIDO (todo passo pela página): B aberta → "Cancelar nota" (o plano no ar) → a página recriada → B '
        'reaberta A CAMINHO → o plano chega (o diálogo abre sobre a lista — D-F194) → "cancelar no fisco" confirmado com B a caminho (a saga '
        'NÃO marca `saving` — D-F197) → B chega sem `saving` → o plano relido da saga recusa (nada foi ao fisco) → a saga RELÊ B (a '
        'releitura no ar) → o operador clica "Transmitir" (`saving`) → a releitura chega e B volta SEM `saving` com o Transmitir no fisco '
        '(D-F191 (b), aceita); o 2º clique em Transmitir é barrado pela trava POR NOTA (D-F183) — nenhuma 2ª chamada à nfse-api', () async {
      final plans = <Completer<Either<Failure, ServiceOrderCancelPlan>>>[];
      when(() => invoice.cancelPlan(_bId)).thenAnswer((_) {
        final c = Completer<Either<Failure, ServiceOrderCancelPlan>>();
        plans.add(c);
        return c.future;
      });
      final transmitB = arm('transmit', _bId);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderCancelFlowRequested(_bId));                              // "Cancelar nota" — o plano no ar
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      final onTheWay = parkNextGet(_bId);
      bloc.add(const ServiceOrderViewRequested(_bId));                                   // B reaberta, a caminho
      await pumpEventQueue(times: 20);
      plans[0].complete(const Right(ServiceOrderCancelPlan(orderId: _bId, blocks: _authorizedBlocks)));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderCancelPlanReady>(), hasLength(1), reason: 'D-F194: o diálogo abre com B a caminho');
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _bId, reason: 'motivo', atAuthority: true));   // a decisão do diálogo
      await pumpEventQueue(times: 20);
      onTheWay.complete(const Right(_b));                                                 // B chega
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).saving, isFalse, reason: 'D-F197');
      final reread = parkNextGet(_bId);
      plans[1].complete(const Left(_refused));                                           // o plano relido da saga recusa → relê B
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_bId));                                // os botões estão livres: Transmitir
      await pumpEventQueue(times: 20);
      final transmitting = _shown(states) as ServiceOrderDetailState;
      reread.complete(const Right(_b));                                                   // a releitura da saga chega
      await pumpEventQueue(times: 20);
      final afterReread = _shown(states) as ServiceOrderDetailState;
      bloc.add(const ServiceOrderTransmitRequested(_bId));                                // o 2º clique (botão livre de novo)
      await pumpEventQueue(times: 20);
      transmitB('ok');
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([transmitting.saving, afterReread.order.id, afterReread.saving], [true, _bId, false], reason: 'D-F191 (b)');
      verify(() => nfse.transmit(_bId)).called(1);                                        // D-F183: a trava por nota barrou o 2º
      verifyNever(() => nfse.cancel(any(), any()));                                       // a saga parou no plano relido: nada foi ao fisco
    });

    test('[RESISTIU] o aperto PROPOSTO (a tolerância só para o GET/POST que FALHOU) não custa nada: no fuzz deste gate (sementes novas e as '
        'do R15, página e diretos) as tolerâncias literais do R14/R15 nunca são usadas por OUTRA causa — todo desfecho engolido antes da '
        'lista é de um GET/POST que falhou (impresso em cada fuzz: "R14 tolerance OUTRA causa" / "R15 tolerance OUTRA causa" ausentes)', () async {
      final page = await fuzz(direct: false, seeds: 150, seedOf: (s) => s * 2654435 + 7, label: 'aperto página', inAirNew: true);
      final direct = await fuzz(direct: true, seeds: 150, seedOf: (s) => s * 40503 + 11, label: 'aperto direto', inAirNew: true);
      // ignore: avoid_print
      print('tolerâncias — página: ${page.entries.where((e) => e.key.contains('tolerance') || e.key.contains('Swallowed')).toList()}\n'
          'diretos: ${direct.entries.where((e) => e.key.contains('tolerance') || e.key.contains('Swallowed')).toList()}');
      expect([page['R14 tolerance OUTRA causa'] ?? 0, page['R15 tolerance OUTRA causa'] ?? 0, direct['R14 tolerance OUTRA causa'] ?? 0,
          direct['R15 tolerance OUTRA causa'] ?? 0], [0, 0, 0, 0]);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  // ---------------------------------------------------------------------
  // 5. `flutter build web` — os arquivos que o flutter_tools lê como UTF-8 (41f8867)
  // ---------------------------------------------------------------------
  group('41f8867 — o que o flutter_tools decodifica como UTF-8 (sem rodar o build)', () {
    test('[RESISTIU] `.gitignore` (lido pela migração ScrubGeneratedPluginRegistrant), `pubspec.yaml`, `.metadata`, `web/index.html`, '
        '`web/manifest.json` e `analysis_options.yaml` do app decodificam como UTF-8 ESTRITO e sem BOM; o `.gitignore` não tem a linha '
        '`lib/generated_plugin_registrant.dart` (a migração nem reescreve o arquivo) — cerca contra o arquivo voltar a cp1252', () {
      const files = ['.gitignore', 'pubspec.yaml', '.metadata', 'web/index.html', 'web/manifest.json', 'analysis_options.yaml'];
      final problems = <String>[];
      for (final path in files) {
        final file = File(path);
        if (!file.existsSync()) {
          problems.add('$path: não existe (o teste roda em apps/web)');
          continue;
        }
        final bytes = file.readAsBytesSync();
        if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) problems.add('$path: BOM');
        try {
          utf8.decode(bytes);
        } on FormatException catch (e) {
          problems.add('$path: fora de UTF-8 — $e');
        }
      }
      expect(problems, isEmpty);
      expect(File('.gitignore').readAsStringSync().contains('generated_plugin_registrant'), isFalse);
    });
  });
}
