import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/entity/service_order_fiscal_entity.dart';
import '../../domain/usecase/service_order_delete.dart';
import '../../domain/usecase/service_order_fiscal_cancel.dart';
import '../../domain/usecase/service_order_fiscal_danfse.dart';
import '../../domain/usecase/service_order_fiscal_get.dart';
import '../../domain/usecase/service_order_fiscal_pending.dart';
import '../../domain/usecase/service_order_fiscal_refresh.dart';
import '../../domain/usecase/service_order_fiscal_transmit_batch.dart';
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
    required this.cancelInvoice,
    required this.batchInvoice,
    required this.fiscalGet,
    required this.transmit,
    required this.fiscalRefresh,
    required this.fiscalXml,
    required this.fiscalDanfse,
    required this.fiscalCancel,
    required this.fiscalPending,
    required this.fiscalTransmitBatch,
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
    on<ServiceOrderInvoiceCancelRequested>(_onInvoiceCancelRequested);
    on<ServiceOrderBatchInvoiceRequested>(_onBatchInvoiceRequested);
    on<ServiceOrderTransmitRequested>(_onTransmitRequested);
    on<ServiceOrderFiscalRefreshRequested>(_onFiscalRefreshRequested);
    on<ServiceOrderFiscalXmlRequested>(_onFiscalXmlRequested);
    on<ServiceOrderFiscalDanfseRequested>(_onFiscalDanfseRequested);
    on<ServiceOrderFiscalCancelRequested>(_onFiscalCancelRequested);
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
  final ServiceOrderCancelInvoice cancelInvoice;
  final ServiceOrderBatchInvoice batchInvoice;

  // Onda 3 — NFS-e pelo ADN (/api/billing/fiscal*)
  final ServiceOrderFiscalGet fiscalGet;
  final ServiceOrderTransmit transmit;
  final ServiceOrderFiscalRefresh fiscalRefresh;
  final ServiceOrderFiscalXml fiscalXml;
  final ServiceOrderFiscalDanfse fiscalDanfse;
  final ServiceOrderFiscalCancel fiscalCancel;
  final ServiceOrderFiscalPendingList fiscalPending;
  final ServiceOrderFiscalTransmitBatch fiscalTransmitBatch;

  /// Aba ativa ('A' abertas | 'F' faturadas) e filtro atual da lista.
  String _status = 'A';
  String _filter = '';

  /// Última página/tamanho aplicados — recarga após operação devolve o
  /// usuário exatamente onde estava (paginação, critério 6).
  int _page = 1;
  int? _pageSize;

  /// OS aberta no detalhe — preserva o conteúdo nos re-emits de
  /// saving/falha sem nova consulta.
  ServiceOrderFull? _detail;

  /// Visão fiscal da nota da OS FATURADA (Onda 3) — carregada junto com o
  /// detalhe; null na OS aberta. [_fiscalFailure] guarda o motivo quando o
  /// GET fiscal falhou (a OS continua legível).
  ServiceOrderFiscalView? _fiscal;
  Failure? _fiscalFailure;

  /// Estado buildável do detalhe a partir do cache — os re-emits de
  /// saving/falha não perdem a visão fiscal.
  ServiceOrderDetailState _detailState(ServiceOrderFull order,
          {bool saving = false}) =>
      ServiceOrderDetailState(
        order: order,
        saving: saving,
        fiscal: _fiscal,
        fiscalFailure: _fiscalFailure,
      );

  Future<void> _reloadList(Emitter<ServiceOrderState> emit) async {
    _detail = null;
    _fiscal = null;
    _fiscalFailure = null;
    emit(ServiceOrderListState(loading: true, status: _status));
    final result = await getlist(_status, _filter,
        page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        emit(ServiceOrderListState(status: _status));
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
          items: paged.items,
          status: _status,
          filter: _filter,
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

  /// Onda 3: a OS FATURADA tem nota — busca a visão fiscal dela. A falha do
  /// GET fiscal NÃO derruba o detalhe nem vira dialog: fica no estado e a
  /// seção "No fisco" mostra o motivo (endpoint fora/ainda não montado).
  Future<void> _loadFiscal(ServiceOrderFull order) async {
    _fiscal = null;
    _fiscalFailure = null;
    if (order.isOpen) return;
    final result = await fiscalGet(order.id);
    result.fold(
      (failure) => _fiscalFailure = failure,
      (view) => _fiscal = view,
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
    await _reloadList(emit);
  }

  Future<void> _onOpenRequested(
      ServiceOrderOpenRequested event, Emitter<ServiceOrderState> emit) async {
    emit(ServiceOrderListState(loading: true, status: _status));
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
    emit(ServiceOrderListState(loading: true, status: _status));
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
    emit(ServiceOrderListState(loading: true, status: _status));
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
    try {
      await _runBatch(event, emit);
    } finally {
      _batchRunning = false;
    }
  }

  bool _batchRunning = false;

  Future<void> _runBatch(ServiceOrderBatchInvoiceRequested event,
      Emitter<ServiceOrderState> emit) async {
    emit(ServiceOrderListState(loading: true, status: _status));
    final ids = event.orderIds.toSet().toList();
    final parts = <BatchInvoiceReport>[];
    Failure? aborted;
    for (var start = 0; start < ids.length; start += batchInvoiceChunkSize) {
      // M4 do gate: bloc fechado (módulo desmontado) = PARAR de enviar blocos —
      // o que já rodou está na aba Faturadas; o resto continua aberto. A
      // política para "fechou a aba do navegador" é a Q-R5.2 (Valdo).
      if (isClosed) return;
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
    if (isClosed) return;
    final failure = aborted;
    if (failure != null && parts.length == 1) {
      // 1º bloco falhou: nada faturado, comportamento de sempre
      emit(ServiceOrderActionFailure(failure));
      await _reloadList(emit);
      return;
    }
    emit(ServiceOrderBatchInvoiceDone(BatchInvoiceReport.merge(parts)));
    await _reloadList(emit);
  }

  /// "Cancelar nota" (Q-G16): a nota some e a OS volta a ABERTA — a lista
  /// reabre na aba Abertas, página 1 (fluxo do processo).
  Future<void> _onInvoiceCancelRequested(
      ServiceOrderInvoiceCancelRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_invoiceCancelling) return; // duplo-clique
    _invoiceCancelling = true;
    final detail = _detail;
    if (detail != null) {
      emit(_detailState(detail, saving: true));
    }
    final result = await cancelInvoice(event.orderId, event.reason);
    _invoiceCancelling = false;
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(_detailState(detail));
      },
      (cancelResult) async {
        emit(ServiceOrderActionSuccess(
          'forms.serviceOrder.invoiceCancelled',
          args: [cancelResult.invoiceNumber],
        ));
        _status = 'A';
        _page = 1;
        await _reloadList(emit);
      },
    );
  }

  bool _invoiceCancelling = false;

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
  // Onda 3 — NFS-e pelo ADN
  // -------------------------------------------------------------------

  /// Ação fiscal de detalhe: marca saving, roda [run], falha vai INTEIRA ao
  /// one-shot (422 FISCAL_DPS_REJECTED com E0xxx em fields[], 409/503
  /// legíveis) e o detalhe volta como estava; sucesso passa o resultado a
  /// [onSuccess], que decide o feedback e se recarrega detalhe ou lista.
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

  /// Transmitir: sucesso 'A' = autorizada com a chave; 'S' = enviado (a
  /// consulta fecha depois). Detalhe recarrega — a voz entra na linha do
  /// tempo.
  Future<void> _onTransmitRequested(ServiceOrderTransmitRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => transmit(event.orderId), (result) async {
        emit(result.authorized
            ? ServiceOrderActionSuccess('forms.serviceOrder.fiscalAuthorized',
                args: [result.accessKey ?? ''])
            : ServiceOrderActionSuccess('forms.serviceOrder.fiscalSent',
                args: ['${result.attempt}']));
        await _reloadDetail(event.orderId, emit);
      });

  /// Consultar: `changed` diz se a linha do tempo mudou; autorizada mostra a
  /// chave. Recarrega o detalhe nos dois casos (lastQueriedAt muda sempre).
  Future<void> _onFiscalRefreshRequested(
          ServiceOrderFiscalRefreshRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => fiscalRefresh(event.orderId), (result) async {
        if (!result.changed) {
          emit(const ServiceOrderActionSuccess(
              'forms.serviceOrder.fiscalRefreshUnchanged'));
        } else if (result.authorized) {
          emit(ServiceOrderActionSuccess('forms.serviceOrder.fiscalAuthorized',
              args: [result.accessKey ?? '']));
        } else {
          emit(const ServiceOrderActionSuccess(
              'forms.serviceOrder.fiscalRefreshChanged'));
        }
        await _reloadDetail(event.orderId, emit);
      });

  /// XML autorizado: one-shot [ServiceOrderFiscalXmlReady] — a página abre
  /// em nova aba; o detalhe volta como estava.
  Future<void> _onFiscalXmlRequested(ServiceOrderFiscalXmlRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => fiscalXml(event.orderId), (xml) async {
        emit(ServiceOrderFiscalXmlReady(xml));
        final detail = _detail;
        if (detail != null) emit(_detailState(detail));
      });

  /// DANFSe: one-shot [ServiceOrderFiscalDanfseReady] (molde BankSlipPdfReady).
  Future<void> _onFiscalDanfseRequested(
          ServiceOrderFiscalDanfseRequested event,
          Emitter<ServiceOrderState> emit) =>
      _fiscalAction(emit, () => fiscalDanfse(event.orderId), (base64) async {
        emit(ServiceOrderFiscalDanfseReady(base64));
        final detail = _detail;
        if (detail != null) emit(_detailState(detail));
      });

  /// Cancelar NFS-e: 'C' = fisco aceitou e a nota local cancelou na mesma
  /// transação — a OS volta a ABERTA (fluxo do "Cancelar nota": lista na
  /// aba Abertas, página 1); 'K' = pedido em voo — o detalhe recarrega
  /// bloqueado até a consulta reconciliar. `warnings[]` vão num one-shot
  /// próprio depois do sucesso. Mesma trava de duplo-clique do cancelamento
  /// local.
  Future<void> _onFiscalCancelRequested(
      ServiceOrderFiscalCancelRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_invoiceCancelling) return;
    _invoiceCancelling = true;
    try {
      await _fiscalAction(emit, () => fiscalCancel(event.orderId, event.reason),
          (result) async {
        emit(ServiceOrderActionSuccess(result.cancelled
            ? 'forms.serviceOrder.fiscalCancelled'
            : 'forms.serviceOrder.fiscalCancelInFlight'));
        if (result.warnings.isNotEmpty) {
          emit(ServiceOrderFiscalWarnings(result.warnings));
        }
        if (result.cancelled) {
          _status = 'A';
          _page = 1;
          await _reloadList(emit);
        } else {
          await _reloadDetail(event.orderId, emit);
        }
      });
    } finally {
      _invoiceCancelling = false;
    }
  }

  /// 1º passo do lote: lista as pendentes e devolve no one-shot — quem
  /// confirma é a página (askDecision). A lista fica em loading enquanto
  /// isso (o botão da AppBar é gated pelo loading).
  Future<void> _onFiscalPendingRequested(
      ServiceOrderFiscalPendingRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_fiscalBatchRunning) return;
    emit(ServiceOrderListState(loading: true, status: _status));
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

  /// 2º passo do lote (confirmado). H1 da Rodada 5: UM lote por vez — o 2º
  /// disparo enquanto o 1º roda é ignorado (a AppBar continua viva e o
  /// lote leva tempo sob contenção do fisco). Fatiamento em blocos de
  /// [fiscalTransmitChunkSize] em SEQUÊNCIA, relatórios agregados; bloco
  /// que falha inteiro DEPOIS de outro já transmitido vira linhas
  /// "recusadas" com o motivo (o relatório do que já foi ao fisco não pode
  /// se perder); só a falha do PRIMEIRO bloco sobe como [Failure].
  Future<void> _onFiscalTransmitBatchRequested(
      ServiceOrderFiscalTransmitBatchRequested event,
      Emitter<ServiceOrderState> emit) async {
    if (_fiscalBatchRunning) return;
    _fiscalBatchRunning = true;
    try {
      await _runFiscalBatch(event, emit);
    } finally {
      _fiscalBatchRunning = false;
    }
  }

  bool _fiscalBatchRunning = false;

  Future<void> _runFiscalBatch(ServiceOrderFiscalTransmitBatchRequested event,
      Emitter<ServiceOrderState> emit) async {
    emit(ServiceOrderListState(loading: true, status: _status));
    final ids = event.orderIds.toSet().toList();
    final parts = <FiscalTransmitBatchReport>[];
    Failure? aborted;
    for (var start = 0; start < ids.length; start += fiscalTransmitChunkSize) {
      if (isClosed) return;
      final chunk = ids.sublist(
          start, (start + fiscalTransmitChunkSize).clamp(0, ids.length));
      final result = await fiscalTransmitBatch(chunk);
      final stop = result.fold<bool>(
        (failure) {
          aborted = failure;
          parts.add(FiscalTransmitBatchReport.fromEntries([
            for (final id in ids.sublist(start))
              FiscalTransmitBatchRow.aborted(
                  orderId: id, message: failure.message),
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
    if (isClosed) return;
    final failure = aborted;
    if (failure != null && parts.length == 1) {
      emit(ServiceOrderActionFailure(failure));
      await _reloadList(emit);
      return;
    }
    emit(ServiceOrderFiscalBatchDone(FiscalTransmitBatchReport.merge(parts)));
    await _reloadList(emit);
  }
}
