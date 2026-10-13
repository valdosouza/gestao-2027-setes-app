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
  bool get _batchInFlight => _batchRunning || _fiscalBatchRunning;

  /// R7-SOC-03 (gate socrático da Rodada 7): a recarga SUPERADA (outra começou
  /// depois — ex.: a página recriada pediu a lista no meio do lote e respondeu
  /// DEPOIS da recarga final dele) não emite: a foto velha nunca sobrescreve a
  /// nova (OS já faturadas voltando a "Abertas").
  int _listGeneration = 0;

  Future<void> _reloadList(Emitter<ServiceOrderState> emit) async {
    _detail = null;
    _fiscal = null;
    _fiscalFailure = null;
    _effect = null;
    _effectFailure = null;
    final generation = ++_listGeneration;
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
    final result = await getlist(_status, _filter,
        page: _page, pageSize: _pageSize, criteria: _criteria);
    if (generation != _listGeneration) return;
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
  Future<void> _reloadDetail(int id, Emitter<ServiceOrderState> emit) async {
    final result = await get(id);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        await _reloadList(emit);
      },
      (full) async {
        _detail = full;
        await _loadFiscal(full);
        emit(_detailState(full));
      },
    );
  }

  /// A OS FATURADA tem nota — busca as DUAS fontes da seção "No fisco" EM
  /// PARALELO (D-F139): a voz do fisco (nfse-api) e o efeito na nota (ERP).
  /// Uma falha não derruba o detalhe nem a outra fonte — fica no estado e a
  /// seção mostra cada uma pelo que é.
  Future<void> _loadFiscal(ServiceOrderFull order) async {
    _fiscal = null;
    _fiscalFailure = null;
    _effect = null;
    _effectFailure = null;
    if (order.isOpen) return;
    final results = await Future.wait([fiscalGet(order.id), fiscalEffectGet(order.id)]);
    (results[0] as Either<Failure, ServiceOrderFiscalView>).fold(
      (failure) => _fiscalFailure = failure,
      (view) => _fiscal = view,
    );
    (results[1] as Either<Failure, ServiceOrderFiscalEffect>).fold(
      (failure) => _effectFailure = failure,
      (effect) => _effect = effect,
    );
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
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
    final result = await post(event.customerId);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        await _reloadList(emit);
      },
      (id) async {
        emit(const ServiceOrderActionSuccess('forms.serviceOrder.opened'));
        await _reloadDetail(id, emit);
      },
    );
  }

  Future<void> _onViewRequested(
      ServiceOrderViewRequested event, Emitter<ServiceOrderState> emit) async {
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
    await _reloadDetail(event.id, emit);
  }

  Future<void> _onCancelRequested(
      ServiceOrderCancelRequested event,
      Emitter<ServiceOrderState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(_detailState(detail, saving: true));
    }
    final result = await delete(event.id);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      (_) async {
        emit(const ServiceOrderActionSuccess('forms.serviceOrder.canceled'));
        await _reloadList(emit);
      },
    );
  }

  Future<void> _onItemSaveRequested(
      ServiceOrderItemSaveRequested event,
      Emitter<ServiceOrderState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(_detailState(detail, saving: true));
    }
    final result = await itemSave(event.orderId, event.itemId, event.input);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      (_) async {
        emit(const ServiceOrderActionSuccess('register.saved'));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  Future<void> _onItemRemoveRequested(
      ServiceOrderItemRemoveRequested event,
      Emitter<ServiceOrderState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(_detailState(detail, saving: true));
    }
    final result = await itemDelete(event.orderId, event.itemId);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      (_) async {
        emit(const ServiceOrderActionSuccess('register.deleted'));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  Future<void> _onMonthlyRunRequested(
      ServiceOrderMonthlyRunRequested event,
      Emitter<ServiceOrderState> emit) async {
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
    final result = await monthlyRun(event.year, event.month);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        await _reloadList(emit);
      },
      (report) async {
        emit(ServiceOrderMonthlyRunDone(report));
        await _reloadList(emit);
      },
    );
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
    emit(ServiceOrderListState(
        loading: true, status: _status, filter: _filter, criteria: _criteria));
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
      // 1º bloco falhou: nada faturado, comportamento de sempre
      emit(ServiceOrderActionFailure(failure));
      await _reloadList(emit);
      return;
    }
    emit(ServiceOrderBatchInvoiceDone(BatchInvoiceReport.merge(parts)));
    await _reloadList(emit);
  }

  Future<void> _onInvoiceRequested(
      ServiceOrderInvoiceRequested event,
      Emitter<ServiceOrderState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(_detailState(detail, saving: true));
    }
    final result = await invoice(event.orderId, event.input);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      (invoiceResult) async {
        emit(ServiceOrderActionSuccess(
          'forms.serviceOrder.invoiceGenerated',
          args: [invoiceResult.invoiceNumber],
        ));
        // Fluxo do processo: a OS faturada aparece na aba Faturadas —
        // troca de aba SEMPRE volta à página 1.
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
  Future<void> _fiscalAction<T>(
    Emitter<ServiceOrderState> emit,
    Future<Either<Failure, T>> Function() run,
    Future<void> Function(T result) onSuccess,
  ) async {
    final detail = _detail;
    if (detail != null) emit(_detailState(detail, saving: true));
    final result = await run();
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      onSuccess,
    );
  }

  /// Desfecho DESCONHECIDO de um ato no fisco (502/503/rede — D-F139): nunca
  /// "não aconteceu". Aviso "resultado incerto — consulte" e o detalhe RELÊ (a
  /// tentativa pode estar em voo). Devolve true quando tratou.
  Future<bool> _unknownOutcome(Failure failure, int orderId, Emitter<ServiceOrderState> emit) async {
    if (!isUnknownAuthorityOutcome(failure)) return false;
    emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalOutcomeUnknown', detail: failure.message));
    await _reloadDetail(orderId, emit);
    return true;
  }

  /// Transmitir (nfse-api): 201 = autorizada com a chave. Recusa (422/409) vai
  /// à ponte; desfecho desconhecido relê. Nunca reenvia sozinho.
  Future<void> _onTransmitRequested(ServiceOrderTransmitRequested event,
      Emitter<ServiceOrderState> emit) async {
    // UM envio por vez (F2B-ADV-07): o 2º clique enquanto o 1º está no fisco é
    // ignorado — a trava da nota na nfse-api barra, mas não se manda o 2º
    if (_transmitting) return;
    _transmitting = true;
    try {
      final detail = _detail;
      if (detail != null) emit(_detailState(detail, saving: true));
      final result = await transmit(event.orderId);
      await result.fold(
        (failure) async {
          if (await _unknownOutcome(failure, event.orderId, emit)) return;
          emit(ServiceOrderActionFailure(failure));
          await _reloadDetail(event.orderId, emit);   // a tentativa R/F entra na linha do tempo
        },
        (r) async {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalAuthorized', args: [r.accessKey ?? '']));
          await _reloadDetail(event.orderId, emit);
        },
      );
    } finally {
      _transmitting = false;
    }
  }

  bool _transmitting = false;

  /// Consultar (nfse-api): `changed` diz se a linha do tempo mudou. Recarrega
  /// nos dois casos (o "consultado em" muda sempre).
  Future<void> _onFiscalRefreshRequested(ServiceOrderFiscalRefreshRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => fiscalRefresh(event.orderId), (result) async {
        if (!result.changed) {
          emit(const ServiceOrderActionSuccess('forms.serviceOrder.fiscalRefreshUnchanged'));
        } else if (result.kind == FiscalTransmissionKind.authorized ||
            result.kind == FiscalTransmissionKind.notCancelled) {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalAuthorized', args: [result.accessKey ?? '']));
        } else {
          emit(const ServiceOrderActionSuccess('forms.serviceOrder.fiscalRefreshChanged'));
        }
        await _reloadDetail(event.orderId, emit);
      });

  /// Reconferir (nfse-api — D-F109): o veredito só escolhe a FRASE
  /// (`nao-exigida` ≠ "pode cancelar"); o detalhe relê e o próximo
  /// "Cancelar nota" lê o PLANO de novo (quem decide).
  Future<void> _onFiscalReconfirmRequested(ServiceOrderFiscalReconfirmRequested event,
      Emitter<ServiceOrderState> emit) async {
    final detail = _detail;
    if (detail != null) emit(_detailState(detail, saving: true));
    final result = await fiscalReconfirm(event.orderId);
    await result.fold(
      (failure) async {
        if (await _unknownOutcome(failure, event.orderId, emit)) return;
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      (r) async {
        final key = r.found
            ? 'forms.serviceOrder.fiscalReconfirmFound'
            : r.verdict == 'provada'
                ? 'forms.serviceOrder.fiscalReconfirmProven'
                : 'forms.serviceOrder.fiscalReconfirmNotProven';
        emit(ServiceOrderFiscalNotice(key, detail: r.verdict));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  /// XML: one-shot [ServiceOrderFiscalXmlReady] — a página abre em nova aba.
  Future<void> _onFiscalXmlRequested(ServiceOrderFiscalXmlRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => fiscalXml(event.orderId), (xml) async {
        emit(ServiceOrderFiscalXmlReady(xml));
        final detail = _detail;
        if (detail != null) emit(_detailState(detail));
      });

  /// DANFSe: one-shot [ServiceOrderFiscalDanfseReady].
  Future<void> _onFiscalDanfseRequested(ServiceOrderFiscalDanfseRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => fiscalDanfse(event.orderId), (base64) async {
        emit(ServiceOrderFiscalDanfseReady(base64));
        final detail = _detail;
        if (detail != null) emit(_detailState(detail));
      });

  /// 1º passo de todo cancelamento (D-F140): o PLANO do ERP → one-shot; a
  /// página decide pelo plano. Falha (403 sem CANCELAR, 409 não faturada,
  /// 503 voz indisponível) vai à ponte.
  Future<void> _onCancelFlowRequested(ServiceOrderCancelFlowRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => cancelPlanGet(event.orderId), (plan) async {
        final detail = _detail;
        if (plan.orderId != 0 && plan.orderId != event.orderId) {
          // o servidor respondeu o plano de OUTRA nota: nunca decidir por ele
          emit(ServiceOrderActionFailure(invalidResponseFailure('plano da OS ${plan.orderId} para a OS ${event.orderId}')));
          if (detail != null) emit(_detailState(detail));
          return;
        }
        if (detail != null) emit(_detailState(detail));
        emit(ServiceOrderCancelPlanReady(plan.withOrderId(event.orderId)));
      });

  /// 2º passo: a SAGA (D-F139). Trava de duplo-clique compartilhada com o
  /// "manter a nota" (decisões EXCLUSIVAS sobre a mesma nota). Depois de tudo
  /// o detalhe RELÊ — o destino vem do status relido (com registro fiscal a
  /// OS fica 'C'; sem, volta a aberta), nunca de uma aba fixa.
  Future<void> _onCancelConfirmed(ServiceOrderCancelConfirmed event,
      Emitter<ServiceOrderState> emit) async {
    if (_invoiceCancelling) return;
    _invoiceCancelling = true;
    try {
      final detail = _detail;
      if (detail != null) emit(_detailState(detail, saving: true));
      final result = await cancelInvoice(event.orderId, event.reason, atAuthority: event.atAuthority);
      await result.fold(
        (saga) async {
          final f = saga.failure;
          if (saga.stage == CancelSagaStage.plan) {
            // D-F149: o plano relido não deixa ir ao fisco — nada foi feito
            if (f.code == FiscalCodes.cancelPlanChanged) {
              emit(const ServiceOrderFiscalNotice('forms.serviceOrder.fiscalSituationChanged'));
            } else {
              emit(ServiceOrderActionFailure(f));
            }
          } else if (saga.stage == CancelSagaStage.authority) {
            if (await _unknownOutcome(f, event.orderId, emit)) return;
            emit(ServiceOrderActionFailure(f));
          } else if (f.code == FiscalCodes.invoiceNotCancellable) {
            // a situação mudou (ex.: outra aba já cancelou a nota): diz e relê —
            // ANTES do authorityCancelled (F2B-SOC-05/ADV-08: com o fisco e a nota
            // já cancelados, "aplicar na nota" dizia o contrário)
            emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalSituationChanged', detail: f.message));
          } else if (saga.authorityCancelled) {
            // o fisco CANCELOU e a nota não: o efeito fica `apply` — a seção
            // oferece "Aplicar o cancelamento na nota" (retomada por derivação)
            emit(ServiceOrderFiscalNotice('forms.serviceOrder.fiscalLocalCancelPending', detail: f.message));
          } else {
            emit(ServiceOrderActionFailure(f));
          }
          await _reloadDetail(event.orderId, emit);
        },
        (outcome) async {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.invoiceCancelled', args: [outcome.result.invoiceNumber]));
          if (outcome.warnings.isNotEmpty) emit(ServiceOrderFiscalWarnings(outcome.warnings));
          await _reloadDetail(event.orderId, emit);
        },
      );
    } finally {
      _invoiceCancelling = false;
    }
  }

  bool _invoiceCancelling = false;

  /// D-F67 "Manter a nota" (efeito `decide`). 409 NOT_APPLICABLE = a situação
  /// mudou fora desta tela — além da ponte, o detalhe RELÊ.
  Future<void> _onFiscalCancelWaiverRequested(ServiceOrderFiscalCancelWaiverRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_invoiceCancelling) return;
    _invoiceCancelling = true;
    try {
      final detail = _detail;
      if (detail != null) emit(_detailState(detail, saving: true));
      final result = await fiscalWaiveCancel(event.orderId, event.reason);
      await result.fold(
        (failure) async {
          emit(ServiceOrderActionFailure(failure));
          if (failure.code == FiscalCodes.cancelWaiverNotApplicable) {
            await _reloadDetail(event.orderId, emit);
          } else if (detail != null) {
            emit(_detailState(detail));
          }
        },
        (waiver) async {
          emit(ServiceOrderActionSuccess(waiver.alreadyWaived
              ? 'forms.serviceOrder.fiscalKeepAlready'
              : 'forms.serviceOrder.fiscalKeepDone'));
          await _reloadDetail(event.orderId, emit);
        },
      );
    } finally {
      _invoiceCancelling = false;
    }
  }

  /// 1º passo do lote: a lista FOTOGRAFADA (todas as páginas, só da OS —
  /// D-F145) → one-shot para a página confirmar.
  Future<void> _onFiscalPendingRequested(ServiceOrderFiscalPendingRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_fiscalBatchRunning) return;
    emit(ServiceOrderListState(loading: true, status: _status, filter: _filter, criteria: _criteria));
    final result = await fiscalPending();
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        await _reloadList(emit);
      },
      (pending) async {
        emit(ServiceOrderFiscalPendingLoaded(pending));
        await _reloadList(emit);
      },
    );
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
      emit(ServiceOrderListState(loading: true, status: _status, filter: _filter, criteria: _criteria));
      // D-F156: [stopBatches] (ou o bloc fechado) é o sinal, conferido a CADA
      // nota — o close do bloc 8 não interrompe este handler (R5-SOC-02)
      final report = await fiscalTransmitBatch(event.orderIds, shouldStop: () => isClosed || _fiscalBatchStop);
      if (isClosed || _fiscalBatchStop) return;
      _fiscalBatchRunning = false;   // D-F169: a recarga final já sai livre
      emit(ServiceOrderFiscalBatchDone(report));
      await _reloadList(emit);
    } finally {
      _fiscalBatchRunning = false;
    }
  }

  bool _fiscalBatchRunning = false;

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
