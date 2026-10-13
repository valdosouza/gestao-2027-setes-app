import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/entity/service_order_fiscal_entity.dart';
import '../../domain/usecase/service_order_cancel_plan_get.dart';
import '../../domain/usecase/service_order_delete.dart';
import '../../domain/usecase/service_order_fiscal_danfse.dart';
import '../../domain/usecase/service_order_fiscal_effect_get.dart';
import '../../domain/usecase/service_order_fiscal_get.dart';
import '../../domain/usecase/service_order_fiscal_pending.dart';
import '../../domain/usecase/service_order_fiscal_reconfirm.dart';
import '../../domain/usecase/service_order_fiscal_refresh.dart';
import '../../domain/usecase/service_order_fiscal_transmit_batch.dart';
import '../../domain/usecase/service_order_fiscal_waive_cancel.dart';
import '../../domain/usecase/service_order_fiscal_xml.dart';
import '../../domain/usecase/service_order_get.dart';
import '../../domain/usecase/service_order_getlist.dart';
import '../../domain/usecase/service_order_batch_invoice.dart';
import '../../domain/usecase/service_order_cancel_invoice.dart';
import '../../domain/usecase/service_order_invoice.dart';
import '../../domain/usecase/service_order_item_delete.dart';
import '../../domain/usecase/service_order_item_save.dart';
import '../../domain/usecase/service_order_monthly_run.dart';
import '../../domain/usecase/service_order_post.dart';
import '../../domain/usecase/service_order_transmit.dart';

import '../../../../shared/search/search_criterion.dart';

part 'service_order_event.dart';
part 'service_order_state.dart';

/// Orquestra as Ordens de Serviço — 1ª TELA DE PROCESSO do produto
/// (Módulo Software House, Onda 4): lista em abas Abertas × Faturadas ↔
/// detalhe da OS. Toda operação (abrir, item, cancelar, rotina mensal,
/// faturar) chama a API e RECARREGA — o totalizer e o status vivem no
/// servidor (DP7). Falhas carregam o [Failure] INTEIRO no one-shot
/// (Framework de Mensagens): a página entrega à PONTE, que deriva o canal
/// — os 409 de negócio (trava D5, ordem faturada) viram dialog de
/// validação com a mensagem da API.
class ServiceOrderBloc extends Bloc<ServiceOrderEvent, ServiceOrderState> {
  ServiceOrderBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.delete,
    required this.itemSave,
    required this.itemDelete,
    required this.monthlyRun,
    required this.invoice,
    required this.batchInvoice,
    required this.fiscalGet,
    required this.fiscalEffectGet,
    required this.cancelPlanGet,
    required this.cancelInvoice,
    required this.transmit,
    required this.fiscalRefresh,
    required this.fiscalReconfirm,
    required this.fiscalXml,
    required this.fiscalDanfse,
    required this.fiscalPending,
    required this.fiscalTransmitBatch,
    required this.fiscalWaiveCancel,
  }) : super(const ServiceOrderListState(loading: true)) {
    on<ServiceOrderListRequested>(_onListRequested);
    on<ServiceOrderOpenRequested>(_onOpenRequested);
    on<ServiceOrderViewRequested>(_onViewRequested);
    on<ServiceOrderBackToListPressed>((event, emit) => _reloadList(emit));
    on<ServiceOrderCancelRequested>(_onCancelRequested);
    on<ServiceOrderItemSaveRequested>(_onItemSaveRequested);
    on<ServiceOrderItemRemoveRequested>(_onItemRemoveRequested);
    on<ServiceOrderMonthlyRunRequested>(_onMonthlyRunRequested);
    on<ServiceOrderInvoiceRequested>(_onInvoiceRequested);
    on<ServiceOrderBatchInvoiceRequested>(_onBatchInvoiceRequested);
    on<ServiceOrderTransmitRequested>(_onTransmitRequested);
    on<ServiceOrderFiscalRefreshRequested>(_onFiscalRefreshRequested);
    on<ServiceOrderFiscalReconfirmRequested>(_onFiscalReconfirmRequested);
    on<ServiceOrderFiscalXmlRequested>(_onFiscalXmlRequested);
    on<ServiceOrderFiscalDanfseRequested>(_onFiscalDanfseRequested);
    on<ServiceOrderCancelFlowRequested>(_onCancelFlowRequested);
    on<ServiceOrderCancelConfirmed>(_onCancelConfirmed);
    on<ServiceOrderFiscalCancelWaiverRequested>(_onFiscalCancelWaiverRequested);
    on<ServiceOrderFiscalPendingRequested>(_onFiscalPendingRequested);
    on<ServiceOrderFiscalTransmitBatchRequested>(
        _onFiscalTransmitBatchRequested);
  }

  final ServiceOrderGetlist getlist;
  final ServiceOrderGet get;
  final ServiceOrderPost post;
  final ServiceOrderDelete delete;
  final ServiceOrderItemSave itemSave;
  final ServiceOrderItemDelete itemDelete;
  final ServiceOrderMonthlyRun monthlyRun;
  final ServiceOrderInvoice invoice;
  final ServiceOrderBatchInvoice batchInvoice;

  // F2b — a NFS-e na nfse-api (D-F4) e os fatos do ERP sobre a nota (D-F115)
  final ServiceOrderFiscalGet fiscalGet;
  final ServiceOrderFiscalEffectGet fiscalEffectGet;
  final ServiceOrderCancelPlanGet cancelPlanGet;

  /// D-F139: a SAGA do cancelamento (composição dos dois repositórios).
  final ServiceOrderCancelInvoice cancelInvoice;
  final ServiceOrderTransmit transmit;
  final ServiceOrderFiscalRefresh fiscalRefresh;
  final ServiceOrderFiscalReconfirm fiscalReconfirm;
  final ServiceOrderFiscalXml fiscalXml;
  final ServiceOrderFiscalDanfse fiscalDanfse;
  final ServiceOrderFiscalPendingList fiscalPending;
  final ServiceOrderFiscalTransmitBatch fiscalTransmitBatch;

  // D-F67 — "Manter a nota" com NFS-e substituída (/api/billing/cancel-waiver)
  final ServiceOrderFiscalWaiveCancel fiscalWaiveCancel;

  /// Aba ativa ('A' abertas | 'F' faturadas) e filtro atual da lista.
  String _status = 'A';
  String _filter = '';

  /// Última página/tamanho aplicados — recarga após operação devolve o
  /// usuário exatamente onde estava (paginação, critério 6).
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8): sobrevive à volta do detalhe e às
  /// operações; troca de aba NÃO a apaga (os critérios valem nas duas abas).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  /// OS aberta no detalhe — preserva o conteúdo nos re-emits de
  /// saving/falha sem nova consulta.
  ServiceOrderFull? _detail;

  /// A seção "No fisco" da OS FATURADA (F2b — D-F139): DUAS fontes e DUAS
  /// falhas — a voz (nfse-api) e o efeito na nota (ERP); null na OS aberta.
  ServiceOrderFiscalView? _fiscal;
  Failure? _fiscalFailure;
  ServiceOrderFiscalEffect? _effect;
  Failure? _effectFailure;

  /// Estado buildável do detalhe a partir do cache — os re-emits de
  /// saving/falha não perdem a visão fiscal.
  ServiceOrderDetailState _detailState(ServiceOrderFull order,
          {bool saving = false}) =>
      ServiceOrderDetailState(
        order: order,
        saving: saving,
        fiscal: _fiscal,
        fiscalFailure: _fiscalFailure,
        effect: _effect,
        effectFailure: _effectFailure,
      );

  /// D-F169 (= Q-F177 (a), Valdo 2026-10-13 — R6-ADV-06/R6-SOC-08): um lote
  /// (faturamento ou fiscal) no ar = a lista sai SEMPRE em loading — a página
  /// recriada no meio do lote (cruzar 1100 px — D-F160) pede a lista e, sem
  /// isto, a trava H1 dos botões reabria e a tela parecia ociosa com o lote
  /// rodando. Cada lote baixa a própria marca ANTES da recarga final.
  /// D-F179 (= Q-F187 (a), Valdo 2026-10-13 — R10-SOC-02/R10-ADV-01): a rotina
  /// mensal e a fotografia das pendentes TAMBÉM — "travado pelo loading, como os
  /// botões de lote" (D-F177) só vale se o loading durar o que a operação dura;
  /// e cada uma com a SUA trava de reentrância (como o `_batchRunning`). Quem
  /// impede operações longas DIFERENTES juntas é a página (todo botão longo é
  /// `state.loading ? null`) — o bloc não cruza as travas (os dois lotes juntos
  /// são um caso já provado da D-F169).
  bool get _batchInFlight => _batchRunning || _fiscalBatchRunning || _monthlyRunning || _fiscalPendingRunning;
  bool _monthlyRunning = false;
  bool _fiscalPendingRunning = false;

  /// UM contador da TELA — "vale o último PEDIDO" (lista ou detalhe). Todo
  /// pedido de tela (recarregar a lista, ver/abrir OS, um ato que troca a tela
  /// pela lista em loading) sobe o contador; a resposta só emite se ainda for a
  /// do último pedido. R7-SOC-03: a recarga SUPERADA nunca sobrescreve a nova;
  /// D-F174: a lista em voo nunca derruba o detalhe aberto DEPOIS dela; R9-SOC-04
  /// (dica do gate socrático da Rodada 9): e o detalhe em voo nunca vence uma
  /// lista pedida DEPOIS dele (troca de aba, página recriada).
  int _screenGeneration = 0;

  /// O pedido de DETALHE em voo (ver/abrir OS — escolha do OPERADOR): o
  /// número de tela dele. Enquanto ele é o último pedido, a tela "é o
  /// detalhe" para as recargas AUTOMÁTICAS (o fim de um lote — D-F174): elas
  /// não o atropelam (gate adversarial da Rodada 9 — a escolha do operador
  /// vence; a recarga automática respeita o detalhe, aberto ou a caminho).
  int? _pendingDetailScreen;

  /// D-F191 (= Q-F195-SOC-05 (a), Valdo 2026-10-13 — R12-SOC-02 = R12-ADV-02): a marca "a caminho" carrega a OS — o fim de um ato com a
  /// MESMA OS a caminho a trata como a tela dela (sem prefixo) e a pede de novo.
  int? _pendingDetailOrder;

  /// D-F187 (= Q-F195-SOC-01 (a), Valdo 2026-10-13 — R12-SOC-01 = R12-ADV-06): o número que a TELA mostra de cada OS já vista (`number ??
  /// id` — o da lista e do cabeçalho; os ids internos diferem dos números) — o desfecho e o relatório do lote citam ESTE, nunca a chave.
  final Map<int, int> _shownNumbers = {};
  int _shownNumberOf(int orderId) => _shownNumbers[orderId] ?? orderId;

  /// D-F191: a tela mostra (ou vai mostrar) a OS [orderId] — o pedido de detalhe em voo, se ele é o último pedido; senão o detalhe aberto.
  bool _showsOrder(int orderId) => _pendingDetailScreen != null && _pendingDetailScreen == _screenGeneration
      ? _pendingDetailOrder == orderId
      : _detail?.id == orderId;

  /// A tela é (ou vai ser) o detalhe — o fim de um lote só mostra o relatório.
  /// R10-SOC-01 (gate socrático do delta da Rodada 10): "aberto" e "a caminho" são UM estado — a marca só morre no MESMO ponto em que o
  /// `_detail` nasce (ou em que a falha volta à lista), nunca entre o GET da OS e a voz do fisco.
  bool get _onDetail =>
      _detail != null || (_pendingDetailScreen != null && _pendingDetailScreen == _screenGeneration);

  /// R10-SOC-03 (dica do gate socrático da Rodada 10): um ato NO detalhe só re-emite tela se a tela que ele capturou ao começar ainda é o
  /// detalhe ABERTO — nenhum pedido de tela depois dele (o contador — página recriada, D-F160) e o detalhe não saiu (um lote confirmado
  /// por cima dele troca a tela pela lista sem subir o contador — D-F174). Senão, só o one-shot do desfecho; a tela de agora fica.
  bool _stillOnDetail(int screen) => screen == _screenGeneration && _detail != null;

  /// D-F199 (= Q-F198-SOC-01 (a) = Q-F198-ADV-01 (a), Valdo 2026-10-13 — autorização em pé; R15-SOC-01 = R15-ADV-01): "a tela que o ato
  /// capturou ainda é o detalhe DESTA OS" — UM predicado para todo ponto que re-emite o detalhe capturado ou tira o operador dele (o
  /// fim sem recarga, a troca de aba do Faturar). As decisões "a tela é a OS do ato" (prefixo, releitura, plano, lista depois de cancelar
  /// a OS) são do [_showsOrder]. A garantia é do bloc, não da página. Por que nada ALCANÇÁVEL mudou (R16-SOC-03 — não é "todo ato nasce no
  /// detalhe dele": a D-F197 e a D-F184 desmentem): (I1) com a marca "a caminho" na tela de agora o `_detail` é nulo; (I2) o `_detail` só
  /// troca de OS por um pedido de tela, que sobe o contador antes do GET; (I3) a página só despacha um ato com a OS do detalhe à vista ou de
  /// um diálogo MODAL aberto sobre ela. Um diálogo que deixe de ser modal, ou uma releitura que troque o `_detail` sem subir o contador, torna
  /// alcançável a região que este predicado fecha — a cerca é o diferencial do fuzz de página do gate R15 (`beginOnOtherDetail` = 0).
  bool _stillOnActDetail(int screen, int orderId) => _stillOnDetail(screen) && _detail?.id == orderId;

  /// O começo de um ato NO detalhe: marca saving e devolve a tela capturada (R10-SOC-03). R14-SOC-05 (gate socrático da Rodada 14 —
  /// endurecimento): só marca o detalhe DA OS do ato — hoje todo ato nasce no detalhe dele (os diálogos são modais), mas a garantia
  /// passa a ser do bloc, não da página (D-F199 fecha o fim do ato pela mesma regra). CONHECIMENTO NEGATIVO (D-F197 = Q-F197-ADV-01
  /// (a)): o ato nascido com a OS A CAMINHO (o plano aberto sobre a lista em loading — D-F194) não marca `saving`; a OS chega com os
  /// botões abertos e o 2º clique cai na trava por nota (D-F183) — o limite conhecido da D-F191 (b), pela porta da D-F194. D-F200
  /// (= Q-F198-SOC-02 (a); premissa corrigida pelo R16-SOC-01): a mesma porta abre a RECONFERÊNCIA (plano com barreira `reconfirm`), que
  /// não tem trava por nota — o 2º clique manda outra consulta. Aceito porque a DUPLICATA É INOFENSIVA, não porque o servidor serializa: é
  /// um `GET /dps` no fisco (sem efeito) e a prova do E2404 pousa por UPDATE condicional à última voz vista (D-F90 — sem trava longa); duas
  /// juntas = dois GET, dois carimbos (o 2º mais novo, ainda posterior ao F) e duas "provada"; só o fisco ACHAR a nota passa pela trava da
  /// nota (reconciliação).
  int _beginDetailAct(Emitter<ServiceOrderState> emit, int orderId) {
    final detail = _detail;
    if (detail != null && detail.id == orderId) emit(_detailState(detail, saving: true));
    return _screenGeneration;
  }

  /// O fim SEM recarga de um ato no detalhe: o detalhe volta (sem saving) só se a tela ainda é o detalhe DESTA OS (R10-SOC-03 + D-F199).
  /// CONHECIMENTO NEGATIVO (D-F201 = Q-F198-ADV-02 (a), R15-ADV-02 — a família da D-F191 (b)): não há contador de atos por OS; o fim
  /// de um ato devolve os botões mesmo com OUTRO ato da MESMA OS ainda no ar (a releitura do 1º reabriu a tela; o operador disparou o
  /// 3º; o fim do 2º — que nasceu DEPOIS de a releitura do 1º ser PEDIDA, por isso no mesmo contador do 3º (R16-SOC-06) — o desmarca). As
  /// travas por nota (Transmitir/Cancelar/Manter) e o servidor protegem; nada conta "atos em voo". D-F203 (= Q-F199-ADV-01 (a), R16-ADV-01):
  /// pela mesma raiz, o Faturar na OS aberta com OUTRO ato dela relido no meio (o contador subiu) RELÊ a OS em vez de trocar para a aba
  /// Faturadas — a nota aparece no detalhe; a aba fica para o operador.
  void _endDetailAct(int screen, int orderId, Emitter<ServiceOrderState> emit) {
    final detail = _detail;
    if (detail != null && _stillOnActDetail(screen, orderId)) emit(_detailState(detail));
  }

  /// D-F182 (= Q-F190 (a), Valdo 2026-10-13 — R11-SOC-01/02 = R11-ADV-02): o fim de um ato que MUDA a OS relê o detalhe se a tela mostra
  /// (ou vai mostrar) a MESMA OS — a do ato, ela reaberta no meio (página recriada) ou ela A CAMINHO (D-F191); outra OS ou a lista: nada a
  /// reler (o desfecho levou o número da OS — [_outcomeOrder]). A releitura é um PEDIDO NOVO de detalhe da OS (o contador sobe): o pedido
  /// em voo — a OS a caminho, ou a releitura de um ato anterior — perde a vez (gate adversarial da Rodada 12, R12-ADV-01: duas releituras
  /// fora de ordem punham "recusada" depois do "autorizada"). CONHECIMENTO NEGATIVO (D-F191 (b) — R12-SOC-03): com OUTRO ato em voo na
  /// mesma OS, o detalhe relido sai SEM `saving` (os botões reabrem) — as travas por nota cobrem Transmitir/Cancelar/Manter e o servidor
  /// protege o resto.
  ///
  /// D-F193 (= Q-F196-SOC-02 (a), Valdo 2026-10-13 — R13-SOC-02 = R13-ADV-01): a releitura de uma OS ABERTA é a de um ATO — morre se o
  /// detalhe sair por um lote confirmado por cima (`act: true` — a regra do R10-SOC-03); só a OS A CAMINHO por escolha do operador
  /// (ver/abrir) segue como pedido "a caminho" e vence o lote (D-F174).
  Future<void> _rereadAfterAct(int orderId, Emitter<ServiceOrderState> emit) {
    if (!_showsOrder(orderId)) return Future.value();
    final onTheWay = _pendingDetailScreen != null && _pendingDetailScreen == _screenGeneration;
    final screen = ++_screenGeneration;
    if (!onTheWay) return _reloadDetail(orderId, emit, generation: screen, act: true);
    _pendingDetailScreen = screen;
    _pendingDetailOrder = orderId;
    return _reloadDetail(orderId, emit, generation: screen);
  }

  /// D-F182/D-F187: o NÚMERO que a tela mostra da OS do ato, quando a tela de agora não é ela (outra OS aberta ou a lista) — o operador
  /// nunca lê o desfecho de X como se fosse de Y; nulo quando a tela é a OS do ato (aberta, reaberta ou a caminho — D-F191).
  /// R14-SOC-05: pela MESMA regra do `_showsOrder` (a tela da OS do ato — aberta ou a caminho), nunca só por "a tela não mudou" — por
  /// isso não recebe a tela capturada (R15-SOC-05: o parâmetro morto convidava a reintroduzir a regra aposentada).
  int? _outcomeOrder(int orderId) => _showsOrder(orderId) ? null : _shownNumberOf(orderId);

  /// A tela vira a LISTA em loading (um ato de lista começou — lote, rotina
  /// mensal, pendentes, abrir/ver OS): o detalhe SAI (`_detail` nulo —
  /// R9-SOC-02: sem isto o fim do lote achava "OS aberta" e a tela ficava no
  /// spinner). [supersede]: o pedido de tela em voo perde a vez (ver/abrir OS);
  /// as operações LONGAS (lotes, rotina mensal, pendentes) passam false — o
  /// detalhe que o operador pediu e ainda está a caminho VENCE (D-F174).
  void _showListLoading(Emitter<ServiceOrderState> emit, {bool supersede = true}) {
    if (supersede) _screenGeneration++;
    _detail = null;
    _fiscal = null;
    _fiscalFailure = null;
    _effect = null;
    _effectFailure = null;
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
  }

  Future<void> _reloadList(Emitter<ServiceOrderState> emit) async {
    _detail = null;
    _fiscal = null;
    _fiscalFailure = null;
    _effect = null;
    _effectFailure = null;
    final generation = ++_screenGeneration;
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
    final result = await getlist(_status, _filter,
        page: _page, pageSize: _pageSize, criteria: _criteria);
    if (generation != _screenGeneration) return;
    await result.fold(
      (failure) async {
        // Q-BA16 (a): critério recusado é descartado + aviso + recarga.
        final pruned = _criteria.withoutRejected(failure);
        if (pruned != null) {
          _criteria = pruned;
          emit(ServiceOrderActionFailure(searchCriterionRemoved(failure)));
          return _reloadList(emit);
        }
        emit(ServiceOrderActionFailure(failure));
        emit(ServiceOrderListState(
        loading: _batchInFlight, status: _status, filter: _filter, criteria: _criteria));
      },
      (paged) async {
        // Página esvaziou (ex.: faturamento tirou o último item da aba) →
        // recua para a última página existente em vez de lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reloadList(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API — D4/D5).
        _page = paged.page;
        _pageSize = paged.pageSize;
        for (final item in paged.items) {
          _shownNumbers[item.id] = item.number ?? item.id;   // D-F187: o número que a tela mostra
        }
        emit(ServiceOrderListState(
          // D-F169: com um lote no ar, a lista sai em loading (a trava H1 continua)
          loading: _batchInFlight,
          items: paged.items,
          status: _status,
          filter: _filter,
          criteria: _criteria,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  /// Recarrega o detalhe (o totalizer é recalculado no servidor a cada
  /// operação de item).
  /// [generation] = o pedido de tela que trouxe o detalhe (ver/abrir OS) ou a
  /// tela que um ato NO detalhe capturou ao começar; se outra tela foi pedida
  /// enquanto o GET voava, o detalhe não volta por cima. [act] (R10-SOC-03): a
  /// recarga de um ATO no detalhe aberto — também não volta se o detalhe SAIU
  /// no meio (um lote confirmado por cima dele).
  Future<void> _reloadDetail(int id, Emitter<ServiceOrderState> emit, {int? generation, bool act = false}) async {
    final screen = generation ?? _screenGeneration;
    bool live() => act ? _stillOnDetail(screen) : screen == _screenGeneration;
    if (!live()) return;   // o ato terminou com a tela já em outro lugar: nem pede a OS
    final result = await get(id);
    if (!live()) return;
    await result.fold(
      (failure) async {
        // R10-SOC-01: a marca morre aqui (a falha volta à lista)…
        if (_pendingDetailScreen == screen) _pendingDetailScreen = null;
        emit(ServiceOrderActionFailure(failure));
        await _reloadList(emit);
      },
      (full) async {
        final fiscal = await _fetchFiscal(full);
        if (!live()) return;
        // …ou aqui, JUNTO com o `_detail` (R10-SOC-01 — antes morria antes da voz do fisco e o fim da rotina mensal achava "lista")
        if (_pendingDetailScreen == screen) _pendingDetailScreen = null;
        // R9-SOC-04/R9-ADV-03: o `_detail` e a voz do fisco nascem JUNTOS, no
        // ponto em que o detalhe é EMITIDO — uma carga abandonada nunca deixa a
        // voz de A no detalhe de B (D-F174 lê o `_detail` no fim dos lotes)
        _fiscal = fiscal.view;
        _fiscalFailure = fiscal.viewFailure;
        _effect = fiscal.effect;
        _effectFailure = fiscal.effectFailure;
        _detail = full;
        _shownNumbers[full.id] = full.number ?? full.id;   // D-F187
        emit(_detailState(full));
      },
    );
  }

  /// A OS FATURADA tem nota — busca as DUAS fontes da seção "No fisco" EM
  /// PARALELO (D-F139): a voz do fisco (nfse-api) e o efeito na nota (ERP).
  /// Uma falha não derruba o detalhe nem a outra fonte — fica no estado e a
  /// seção mostra cada uma pelo que é.
  /// R9-ADV-03 (gate adversarial da Rodada 9): devolve as duas fontes como
  /// VALOR (antes gravava no bloc no meio da carga — a carga abandonada de A
  /// sobrescrevia a voz no detalhe de B).
  Future<_FiscalSnapshot> _fetchFiscal(ServiceOrderFull order) async {
    if (order.isOpen) return const _FiscalSnapshot();
    final results = await Future.wait([fiscalGet(order.id), fiscalEffectGet(order.id)]);
    ServiceOrderFiscalView? view;
    Failure? viewFailure;
    ServiceOrderFiscalEffect? effect;
    Failure? effectFailure;
    (results[0] as Either<Failure, ServiceOrderFiscalView>).fold(
      (failure) => viewFailure = failure,
      (v) => view = v,
    );
    (results[1] as Either<Failure, ServiceOrderFiscalEffect>).fold(
      (failure) => effectFailure = failure,
      (e) => effect = e,
    );
    return _FiscalSnapshot(view: view, viewFailure: viewFailure, effect: effect, effectFailure: effectFailure);
  }

  Future<void> _onListRequested(
      ServiceOrderListRequested event, Emitter<ServiceOrderState> emit) async {
    _status = event.status ?? _status;
    _filter = event.filter ?? _filter;
    // Troca de aba/filtro SEMPRE volta à página 1 (default do evento);
    // só a navegação da barra manda outra página.
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reloadList(emit);
  }

  Future<void> _onOpenRequested(
      ServiceOrderOpenRequested event, Emitter<ServiceOrderState> emit) async {
    _showListLoading(emit);   // R9-SOC-04 (i): a lista em voo perde a vez já no POST
    final screen = _screenGeneration;
    _pendingDetailScreen = screen;
    _pendingDetailOrder = null;   // D-F191: a OS ainda não existe (o POST dá o id)
    final result = await post(event.customerId);
    await result.fold(
      (failure) async {
        if (_pendingDetailScreen == screen) _pendingDetailScreen = null;
        emit(ServiceOrderActionFailure(failure));
        if (screen == _screenGeneration) await _reloadList(emit);
      },
      (id) async {
        if (_pendingDetailScreen == screen) _pendingDetailOrder = id;
        emit(const ServiceOrderActionSuccess('forms.serviceOrder.opened'));
        await _reloadDetail(id, emit, generation: screen);
      },
    );
  }

  Future<void> _onViewRequested(
      ServiceOrderViewRequested event, Emitter<ServiceOrderState> emit) async {
    _showListLoading(emit);   // D-F174/R9-SOC-04: a lista em voo não emite por cima do detalhe que vai abrir
    _pendingDetailScreen = _screenGeneration;
    _pendingDetailOrder = event.id;   // D-F191
    await _reloadDetail(event.id, emit, generation: _screenGeneration);
  }

  Future<void> _onCancelRequested(
      ServiceOrderCancelRequested event,
      Emitter<ServiceOrderState> emit) async {
    final screen = _beginDetailAct(emit, event.id);
    final result = await delete(event.id);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.id)));
        _endDetailAct(screen, event.id, emit);
      },
      (_) async {
        emit(ServiceOrderActionSuccess('forms.serviceOrder.canceled', orderNumber: _outcomeOrder(event.id)));
        // D-F182/D-F191: a OS cancelada (excluída) reaberta — ou a caminho — no meio também volta à lista; D-F199: só a tela DELA
        // (aberta, reaberta ou a caminho) — com outra OS na tela o operador fica onde está
        if (_showsOrder(event.id)) await _reloadList(emit);
      },
    );
  }

  Future<void> _onItemSaveRequested(
      ServiceOrderItemSaveRequested event,
      Emitter<ServiceOrderState> emit) async {
    final screen = _beginDetailAct(emit, event.orderId);
    final result = await itemSave(event.orderId, event.itemId, event.input);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.orderId)));
        _endDetailAct(screen, event.orderId, emit);
      },
      (_) async {
        emit(ServiceOrderActionSuccess('register.saved', orderNumber: _outcomeOrder(event.orderId)));
        await _rereadAfterAct(event.orderId, emit);
      },
    );
  }

  Future<void> _onItemRemoveRequested(
      ServiceOrderItemRemoveRequested event,
      Emitter<ServiceOrderState> emit) async {
    final screen = _beginDetailAct(emit, event.orderId);
    final result = await itemDelete(event.orderId, event.itemId);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.orderId)));
        _endDetailAct(screen, event.orderId, emit);
      },
      (_) async {
        emit(ServiceOrderActionSuccess('register.deleted', orderNumber: _outcomeOrder(event.orderId)));
        await _rereadAfterAct(event.orderId, emit);
      },
    );
  }

  Future<void> _onMonthlyRunRequested(
      ServiceOrderMonthlyRunRequested event,
      Emitter<ServiceOrderState> emit) async {
    // D-F179: uma rotina por vez (o 2º clique é ignorado — o servidor protege a competência, mas não se manda o 2º)
    if (_monthlyRunning) return;
    _monthlyRunning = true;
    try {
      _showListLoading(emit, supersede: false);
      final result = await monthlyRun(event.year, event.month);
      _monthlyRunning = false;   // D-F169/D-F179: a recarga final já sai livre
      // D-F177 (= Q-F185 (a), Valdo 2026-10-13 — R9-SOC-03): a rotina leva minutos com N contratos — a OS aberta (ou a caminho) no meio
      // fica; o desfecho aparece e voltar à lista recarrega (a regra da D-F174 em TODA saída longa)
      await result.fold(
        (failure) async {
          emit(ServiceOrderActionFailure(failure));
          if (_onDetail) return;
          await _reloadList(emit);
        },
        (report) async {
          emit(ServiceOrderMonthlyRunDone(report));
          if (_onDetail) return;
          await _reloadList(emit);
        },
      );
    } finally {
      _monthlyRunning = false;
    }
  }

  /// LOTE da cobrança mensal (D6/D7): o relatório volta no one-shot
  /// [ServiceOrderBatchInvoiceDone] e a lista recarrega. Falha do LOTE
  /// INTEIRO (sem privilégio, corpo inválido) é [Failure] como qualquer
  /// outra; ordem recusada NÃO é falha — é linha do relatório.
  ///
  /// D27 (Q-P6, Valdo 2026-09-19): a API aceita até [batchInvoiceChunkSize]
  /// ordens por requisição. A seleção é fatiada aqui, em SEQUÊNCIA (um bloco
  /// por vez — dois em paralelo dobrariam a contenção na mesma institution), e
  /// os relatórios são agregados num só. Bloco que falha INTEIRO depois de
  /// outro já ter faturado não pode virar [Failure] — o relatório do que já
  /// foi cobrado se perderia; suas ordens (e as dos blocos seguintes, que não
  /// são tentados) entram como recusadas "tente de novo" com o motivo. Só
  /// quando o PRIMEIRO bloco falha e nada foi faturado a falha sobe como
  /// [Failure], para a ponte tratar 403/400 como sempre.
  Future<void> _onBatchInvoiceRequested(
      ServiceOrderBatchInvoiceRequested event,
      Emitter<ServiceOrderState> emit) async {
    // H1 do gate socrático da Rodada 5: o lote leva minutos sob contenção e a
    // AppBar continua viva — um 2º clique disparava um lote IGUAL em paralelo
    // (contenção auto-infligida + dois relatórios se sobrescrevendo). Um lote
    // por vez, como o cancelamento de nota; o botão também é desabilitado no
    // loading pela página.
    if (_batchRunning) return;
    _batchRunning = true;
    _invoiceBatchStop = false;
    try {
      await _runBatch(event, emit);
    } finally {
      _batchRunning = false;
    }
  }

  bool _batchRunning = false;

  Future<void> _runBatch(ServiceOrderBatchInvoiceRequested event,
      Emitter<ServiceOrderState> emit) async {
    _showListLoading(emit, supersede: false);
    final ids = event.orderIds.toSet().toList();
    final parts = <BatchInvoiceReport>[];
    Failure? aborted;
    for (var start = 0; start < ids.length; start += batchInvoiceChunkSize) {
      // M4 do gate: a tela saiu (módulo desmontado) = PARAR de enviar blocos —
      // o que já rodou está na aba Faturadas; o resto continua aberto.
      // D-F156 (= Q-F164 (a) — decide a Q-R5.2): [stopBatches] (o onDispose
      // do módulo — D-F160). O close do bloc 8 NÃO interrompe este
      // handler (só cancela as emissões) — por isso o sinal é conferido a CADA bloco.
      if (isClosed || _invoiceBatchStop) return;
      final chunk = ids.sublist(
          start, (start + batchInvoiceChunkSize).clamp(0, ids.length));
      final result = await batchInvoice(chunk, event.input);
      final stop = result.fold<bool>(
        (failure) {
          aborted = failure;
          parts.add(BatchInvoiceReport.fromEntries([
            for (final id in ids.sublist(start))
              BatchInvoiceEntry.aborted(orderId: id, error: failure.message),
          ]));
          return true;
        },
        (report) {
          parts.add(report);
          return false;
        },
      );
      if (stop) break;
    }
    if (isClosed || _invoiceBatchStop) return;
    final failure = aborted;
    _batchRunning = false;   // D-F169: a recarga final já sai livre
    if (failure != null && parts.length == 1) {
      // 1º bloco falhou: nada faturado, comportamento de sempre — e a OS aberta
      // no meio fica (D-F174 também no "fim" por falha — R9-SOC-01)
      emit(ServiceOrderActionFailure(failure));
      if (_onDetail) return;
      await _reloadList(emit);
      return;
    }
    final merged = BatchInvoiceReport.merge(parts);
    // D-F187: o relatório cita o NÚMERO que a tela mostra de cada OS
    emit(ServiceOrderBatchInvoiceDone(merged, numbers: {for (final e in merged.results) e.orderId: _shownNumberOf(e.orderId)}));
    // D-F174: o operador abriu uma OS no meio do lote (que pode levar dezenas de minutos) — o fim mostra o relatório e NÃO o tira do
    // detalhe; voltar à lista recarrega (BackToList) — aberto OU a caminho. CONHECIMENTO NEGATIVO (D-F178 = Q-F186 (a)): o detalhe
    // preservado NÃO é relido no fim do lote — se a OS aberta fosse do lote, ficaria com o status de antes (a UI não chega lá: durante o
    // lote a lista é spinner e o FAB cria OS NOVA; o servidor protege com 409/trava da nota); reler no meio de uma ação reabriria os
    // botões em voo
    if (_onDetail) return;
    await _reloadList(emit);
  }

  Future<void> _onInvoiceRequested(
      ServiceOrderInvoiceRequested event,
      Emitter<ServiceOrderState> emit) async {
    final screen = _beginDetailAct(emit, event.orderId);
    final result = await invoice(event.orderId, event.input);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.orderId)));
        _endDetailAct(screen, event.orderId, emit);
      },
      (invoiceResult) async {
        emit(ServiceOrderActionSuccess(
          'forms.serviceOrder.invoiceGenerated',
          args: [invoiceResult.invoiceNumber],
          orderNumber: _outcomeOrder(event.orderId),
        ));
        // Fluxo do processo: a OS faturada aparece na aba Faturadas —
        // troca de aba SEMPRE volta à página 1. R10-SOC-03: só se a tela ainda é
        // o detalhe (outra tela pedida no meio vence — vale o último pedido);
        // D-F182: a MESMA OS reaberta no meio é relida (mostra a nota); D-F199: a troca de aba só sobre o detalhe DESTA OS (com
        // outra OS aberta na mesma tela o operador fica onde está — o `_rereadAfterAct` não relê o que a tela não mostra)
        if (!_stillOnActDetail(screen, event.orderId)) {
          await _rereadAfterAct(event.orderId, emit);   // D-F182/D-F191: a MESMA OS reaberta (ou a caminho) mostra a nota
          return;
        }
        _status = 'F';
        _page = 1;
        await _reloadList(emit);
      },
    );
  }

  // -------------------------------------------------------------------
  // F2b — a NFS-e na nfse-api + os fatos do ERP (D-F139…D-F145)
  // -------------------------------------------------------------------

  /// Ação fiscal de detalhe: marca saving, roda [run], falha vai INTEIRA ao
  /// one-shot e o detalhe volta como estava; sucesso passa o resultado a
  /// [onSuccess], que decide o feedback e se recarrega.
  /// R10-SOC-03: [onSuccess] recebe a tela capturada ao começar; D-F182: a
  /// falha leva o número da OS quando a tela de agora é outra.
  Future<void> _fiscalAction<T>(
    Emitter<ServiceOrderState> emit,
    int orderId,
    Future<Either<Failure, T>> Function() run,
    Future<void> Function(T result, int screen) onSuccess,
  ) async {
    final screen = _beginDetailAct(emit, orderId);
    final result = await run();
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(orderId)));
        _endDetailAct(screen, orderId, emit);
      },
      (r) => onSuccess(r, screen),
    );
  }

  /// Desfecho DESCONHECIDO de um ato no fisco (502/503/rede — D-F139): nunca
  /// "não aconteceu". Aviso "resultado incerto — consulte" e o detalhe RELÊ (a
  /// tentativa pode estar em voo). Devolve true quando tratou.
  Future<bool> _unknownOutcome(Failure failure, int orderId, Emitter<ServiceOrderState> emit) async {
    if (!isUnknownAuthorityOutcome(failure)) return false;
    emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalOutcomeUnknown',
        detail: failure.message, orderNumber: _outcomeOrder(orderId)));
    await _rereadAfterAct(orderId, emit);
    return true;
  }

  /// Transmitir (nfse-api): 201 = autorizada com a chave. Recusa (422/409) vai
  /// à ponte; desfecho desconhecido relê. Nunca reenvia sozinho.
  Future<void> _onTransmitRequested(ServiceOrderTransmitRequested event,
      Emitter<ServiceOrderState> emit) async {
    // UM envio por vez POR NOTA (F2B-ADV-07; D-F183): o 2º clique na MESMA nota
    // enquanto o 1º está no fisco é ignorado — a trava da nota na nfse-api barra,
    // mas não se manda o 2º; o clique em OUTRA nota vai
    if (!_transmitting.add(event.orderId)) return;
    try {
      _beginDetailAct(emit, event.orderId);   // a tela capturada não decide nada aqui: o fim RELÊ (D-F182)
      final result = await transmit(event.orderId);
      await result.fold(
        (failure) async {
          if (await _unknownOutcome(failure, event.orderId, emit)) return;
          emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.orderId)));
          await _rereadAfterAct(event.orderId, emit);   // a tentativa R/F entra na linha do tempo
        },
        (r) async {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalAuthorized',
              args: [r.accessKey ?? ''], orderNumber: _outcomeOrder(event.orderId)));
          await _rereadAfterAct(event.orderId, emit);
        },
      );
    } finally {
      _transmitting.remove(event.orderId);
    }
  }

  /// D-F183 (= Q-F191 (a), Valdo 2026-10-13 — R11-SOC-02 = R11-ADV-03): a trava
  /// de duplo clique é POR NOTA (as OS em voo) — quem protege a nota é a trava
  /// DELA na nfse-api/ERP; a do bloc é só contra o duplo clique na mesma nota.
  final Set<int> _transmitting = {};

  /// Consultar (nfse-api): `changed` diz se a linha do tempo mudou. Recarrega
  /// nos dois casos (o "consultado em" muda sempre).
  Future<void> _onFiscalRefreshRequested(ServiceOrderFiscalRefreshRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, event.orderId, () => fiscalRefresh(event.orderId), (result, screen) async {
        final about = _outcomeOrder(event.orderId);
        if (!result.changed) {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalRefreshUnchanged', orderNumber: about));
        } else if (result.kind == FiscalTransmissionKind.authorized ||
            result.kind == FiscalTransmissionKind.notCancelled) {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalAuthorized', args: [result.accessKey ?? ''], orderNumber: about));
        } else {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalRefreshChanged', orderNumber: about));
        }
        await _rereadAfterAct(event.orderId, emit);
      });

  /// Reconferir (nfse-api — D-F109): o veredito só escolhe a FRASE
  /// (`nao-exigida` ≠ "pode cancelar"); o detalhe relê e o próximo
  /// "Cancelar nota" lê o PLANO de novo (quem decide).
  Future<void> _onFiscalReconfirmRequested(ServiceOrderFiscalReconfirmRequested event,
      Emitter<ServiceOrderState> emit) async {
    final screen = _beginDetailAct(emit, event.orderId);
    final result = await fiscalReconfirm(event.orderId);
    await result.fold(
      (failure) async {
        if (await _unknownOutcome(failure, event.orderId, emit)) return;
        emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.orderId)));
        _endDetailAct(screen, event.orderId, emit);
      },
      (r) async {
        final key = r.found
            ? 'forms.serviceOrder.fiscalReconfirmFound'
            : r.verdict == 'provada'
                ? 'forms.serviceOrder.fiscalReconfirmProven'
                : 'forms.serviceOrder.fiscalReconfirmNotProven';
        emit(ServiceOrderFiscalNotice(key, detail: r.verdict, orderNumber: _outcomeOrder(event.orderId)));
        await _rereadAfterAct(event.orderId, emit);
      },
    );
  }

  /// XML: one-shot [ServiceOrderFiscalXmlReady] — a página abre em nova aba.
  Future<void> _onFiscalXmlRequested(ServiceOrderFiscalXmlRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, event.orderId, () => fiscalXml(event.orderId), (xml, screen) async {
        emit(ServiceOrderFiscalXmlReady(xml, orderNumber: _outcomeOrder(event.orderId)));   // D-F189/Q-F195-ADV-01
        _endDetailAct(screen, event.orderId, emit);
      });

  /// DANFSe: one-shot [ServiceOrderFiscalDanfseReady].
  Future<void> _onFiscalDanfseRequested(ServiceOrderFiscalDanfseRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, event.orderId, () => fiscalDanfse(event.orderId), (base64, screen) async {
        emit(ServiceOrderFiscalDanfseReady(base64, orderNumber: _outcomeOrder(event.orderId)));   // D-F189/Q-F195-ADV-01
        _endDetailAct(screen, event.orderId, emit);
      });

  /// 1º passo de todo cancelamento (D-F140): o PLANO do ERP → one-shot; a
  /// página decide pelo plano. Falha (403 sem CANCELAR, 409 não faturada,
  /// 503 voz indisponível) vai à ponte.
  Future<void> _onCancelFlowRequested(ServiceOrderCancelFlowRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, event.orderId, () => cancelPlanGet(event.orderId), (plan, screen) async {
        if (plan.orderId != 0 && plan.orderId != event.orderId) {
          // o servidor respondeu o plano de OUTRA nota: nunca decidir por ele
          emit(ServiceOrderActionFailure(invalidResponseFailure('plano da OS ${plan.orderId} para a OS ${event.orderId}'),
              orderNumber: _outcomeOrder(event.orderId)));
          _endDetailAct(screen, event.orderId, emit);
          return;
        }
        // R10-SOC-03: a decisão do cancelamento só abre sobre o detalhe que a pediu (outra OS ou a lista = nada a decidir aqui); D-F189
        // (= Q-F195-SOC-03 (a)): a MESMA OS reaberta no meio também abre; D-F194 (= Q-F196-SOC-03 (a)): e a MESMA OS a caminho
        // CONHECIMENTO NEGATIVO (D-F196 = Q-F197-SOC-02 (a)): com a tela em OUTRA OS ou na lista o plano some SEM aviso — o GET do plano
        // não tem efeito, e uma frase convidaria a decidir o cancelamento sem ver a OS (o motivo do R10-SOC-03); o operador abre a OS e pede
        // D-F199: pela tela DESTA OS (aberta, reaberta ou a caminho) — nunca por "a tela não mudou" (o plano da A não abre sobre a B)
        if (!_showsOrder(event.orderId)) return;
        _endDetailAct(screen, event.orderId, emit);
        emit(ServiceOrderCancelPlanReady(plan.withOrderId(event.orderId)));
      });

  /// 2º passo: a SAGA (D-F139). Trava de duplo-clique compartilhada com o
  /// "manter a nota" (decisões EXCLUSIVAS sobre a mesma nota). Depois de tudo
  /// o detalhe RELÊ — o destino vem do status relido (com registro fiscal a
  /// OS fica 'C'; sem, volta a aberta), nunca de uma aba fixa.
  Future<void> _onCancelConfirmed(ServiceOrderCancelConfirmed event,
      Emitter<ServiceOrderState> emit) async {
    // D-F183: decisões EXCLUSIVAS sobre a MESMA nota (cancelar × manter) — a trava é por nota
    if (!_invoiceCancelling.add(event.orderId)) return;
    try {
      _beginDetailAct(emit, event.orderId);   // idem: todo fim da saga relê pelo [_rereadAfterAct]
      final result = await cancelInvoice(event.orderId, event.reason, atAuthority: event.atAuthority);
      int? about() => _outcomeOrder(event.orderId);
      await result.fold(
        (saga) async {
          final f = saga.failure;
          if (saga.stage == CancelSagaStage.plan) {
            // D-F149: o plano relido não deixa ir ao fisco — nada foi feito
            if (f.code == FiscalCodes.cancelPlanChanged) {
              emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalSituationChanged', orderNumber: about()));
            } else {
              emit(ServiceOrderActionFailure(f, orderNumber: about()));
            }
          } else if (saga.stage == CancelSagaStage.authority) {
            if (await _unknownOutcome(f, event.orderId, emit)) return;
            emit(ServiceOrderActionFailure(f, orderNumber: about()));
          } else if (f.code == FiscalCodes.invoiceNotCancellable) {
            // a situação mudou (ex.: outra aba já cancelou a nota): diz e relê —
            // ANTES do authorityCancelled (F2B-SOC-05/ADV-08: com o fisco e a nota
            // já cancelados, "aplicar na nota" dizia o contrário)
            emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalSituationChanged', detail: f.message, orderNumber: about()));
          } else if (saga.authorityCancelled) {
            // o fisco CANCELOU e a nota não: o efeito fica `apply` — a seção
            // oferece "Aplicar o cancelamento na nota" (retomada por derivação)
            emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalLocalCancelPending', detail: f.message, orderNumber: about()));
          } else {
            emit(ServiceOrderActionFailure(f, orderNumber: about()));
          }
          await _rereadAfterAct(event.orderId, emit);
        },
        (outcome) async {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.invoiceCancelled',
              args: [outcome.result.invoiceNumber], orderNumber: about()));
          if (outcome.warnings.isNotEmpty) emit(ServiceOrderFiscalWarnings(outcome.warnings, orderNumber: about()));
          await _rereadAfterAct(event.orderId, emit);
        },
      );
    } finally {
      _invoiceCancelling.remove(event.orderId);
    }
  }

  /// D-F183: as notas com uma decisão de cancelamento/"manter" em voo (trava por nota).
  final Set<int> _invoiceCancelling = {};

  /// D-F67 "Manter a nota" (efeito `decide`). 409 NOT_APPLICABLE = a situação
  /// mudou fora desta tela — além da ponte, o detalhe RELÊ.
  Future<void> _onFiscalCancelWaiverRequested(ServiceOrderFiscalCancelWaiverRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (!_invoiceCancelling.add(event.orderId)) return;   // D-F183: por nota
    try {
      final screen = _beginDetailAct(emit, event.orderId);
      final result = await fiscalWaiveCancel(event.orderId, event.reason);
      await result.fold(
        (failure) async {
          emit(ServiceOrderActionFailure(failure, orderNumber: _outcomeOrder(event.orderId)));
          if (failure.code == FiscalCodes.cancelWaiverNotApplicable) {
            await _rereadAfterAct(event.orderId, emit);
          } else {
            _endDetailAct(screen, event.orderId, emit);
          }
        },
        (waiver) async {
          emit(ServiceOrderActionSuccess(
              waiver.alreadyWaived ? 'forms.serviceOrder.fiscalKeepAlready' : 'forms.serviceOrder.fiscalKeepDone',
              orderNumber: _outcomeOrder(event.orderId)));
          await _rereadAfterAct(event.orderId, emit);
        },
      );
    } finally {
      _invoiceCancelling.remove(event.orderId);
    }
  }

  /// 1º passo do lote: a lista FOTOGRAFADA (todas as páginas, só da OS —
  /// D-F145) → one-shot para a página confirmar.
  Future<void> _onFiscalPendingRequested(ServiceOrderFiscalPendingRequested event,
      Emitter<ServiceOrderState> emit) async {
    // D-F179: uma fotografia por vez (o 2º clique daria dois diálogos de confirmação) — e nunca com o lote fiscal no ar
    if (_fiscalPendingRunning || _fiscalBatchRunning) return;
    _fiscalPendingRunning = true;
    try {
      _showListLoading(emit, supersede: false);
      final result = await fiscalPending();
      _fiscalPendingRunning = false;   // D-F169/D-F179: a recarga final já sai livre
      // D-F177: a fotografia das pendentes (todas as páginas) pode demorar — a OS aberta no meio fica (a confirmação abre por cima dela)
      await result.fold(
        (failure) async {
          emit(ServiceOrderActionFailure(failure));
          if (_onDetail) return;
          await _reloadList(emit);
        },
        (pending) async {
          // D-F187: o lote fiscal cita o nº da NOTA que a pendente traz
          _pendingNoteNumbers = {for (final p in pending) p.orderId: p.number};
          emit(ServiceOrderFiscalPendingLoaded(pending));
          if (_onDetail) return;
          await _reloadList(emit);
        },
      );
    } finally {
      _fiscalPendingRunning = false;
    }
  }

  /// 2º passo (confirmado): UM lote por vez; o lote roda no app, 1 nota por
  /// vez, e PARA em erro sistêmico (usecase). Bloc fechado = parar sem
  /// relatório (o que já foi ao fisco está na lista).
  Future<void> _onFiscalTransmitBatchRequested(ServiceOrderFiscalTransmitBatchRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_fiscalBatchRunning) return;
    _fiscalBatchRunning = true;
    _fiscalBatchStop = false;
    try {
      _showListLoading(emit, supersede: false);
      // D-F156: [stopBatches] (ou o bloc fechado) é o sinal, conferido a CADA
      // nota — o close do bloc 8 não interrompe este handler (R5-SOC-02)
      final report = await fiscalTransmitBatch(event.orderIds, shouldStop: () => isClosed || _fiscalBatchStop);
      if (isClosed || _fiscalBatchStop) return;
      _fiscalBatchRunning = false;   // D-F169: a recarga final já sai livre
      emit(ServiceOrderFiscalBatchDone(report, noteNumbers: {
        for (final id in event.orderIds)
          if (_pendingNoteNumbers[id] != null) id: _pendingNoteNumbers[id]!,
      }));
      if (_onDetail) return;   // D-F174: com a OS aberta (ou a caminho), só o relatório (voltar à lista recarrega)
      await _reloadList(emit);
    } finally {
      _fiscalBatchRunning = false;
    }
  }

  bool _fiscalBatchRunning = false;

  /// D-F187: o nº da NOTA de cada OS da última fotografia das pendentes (o lote fiscal se identifica por ele).
  Map<int, String?> _pendingNoteNumbers = const {};

  /// A tela saiu ([stopBatches]) — o lote fiscal para depois da nota em voo
  /// (D-F145; F2B-ADV-03) e o de faturamento depois do bloco em voo (D-F156).
  bool _fiscalBatchStop = false;
  bool _invoiceBatchStop = false;

  /// A TELA SAIU — o `onDispose` do módulo (D-F156 = Q-F164 (a); D-F160 =
  /// Q-F168 (a), Valdo 2026-10-13: só ele — o dispose da página roda também
  /// na troca de layout ao cruzar 1100 px). Os dois lotes param depois da unidade em
  /// voo (a nota no fisco; o bloco de faturamento): o que já foi feito fica na
  /// lista; tela fechada = sem relatório. Síncrono e seguro com o bloc já
  /// fechado. Conhecimento negativo (R5-SOC-02, sonda no bloc 8.1.4): o
  /// `close()` termina logo e o `isClosed` vira true, mas o handler em
  /// andamento NÃO é interrompido — segue até o fim com as emissões viradas
  /// no-op; por isso os laços conferem o sinal a cada unidade.
  void stopBatches() {
    _fiscalBatchStop = true;
    _invoiceBatchStop = true;
  }
}

/// As duas fontes da seção "No fisco" de UMA OS (a voz da nfse-api e o efeito
/// do ERP) — um valor, gravado no bloc só junto do detalhe que descreve.
class _FiscalSnapshot {
  const _FiscalSnapshot({this.view, this.viewFailure, this.effect, this.effectFailure});
  final ServiceOrderFiscalView? view;
  final Failure? viewFailure;
  final ServiceOrderFiscalEffect? effect;
  final Failure? effectFailure;
}
