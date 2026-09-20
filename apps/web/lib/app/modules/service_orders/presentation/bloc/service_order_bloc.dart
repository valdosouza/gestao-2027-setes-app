import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/usecase/service_order_delete.dart';
import '../../domain/usecase/service_order_get.dart';
import '../../domain/usecase/service_order_getlist.dart';
import '../../domain/usecase/service_order_batch_invoice.dart';
import '../../domain/usecase/service_order_cancel_invoice.dart';
import '../../domain/usecase/service_order_invoice.dart';
import '../../domain/usecase/service_order_item_delete.dart';
import '../../domain/usecase/service_order_item_save.dart';
import '../../domain/usecase/service_order_monthly_run.dart';
import '../../domain/usecase/service_order_post.dart';

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

  Future<void> _reloadList(Emitter<ServiceOrderState> emit) async {
    _detail = null;
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
        emit(ServiceOrderDetailState(order: full));
      },
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
      emit(ServiceOrderDetailState(order: detail, saving: true));
    }
    final result = await delete(event.id);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(ServiceOrderDetailState(order: detail));
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
      emit(ServiceOrderDetailState(order: detail, saving: true));
    }
    final result = await itemSave(event.orderId, event.itemId, event.input);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(ServiceOrderDetailState(order: detail));
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
      emit(ServiceOrderDetailState(order: detail, saving: true));
    }
    final result = await itemDelete(event.orderId, event.itemId);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(ServiceOrderDetailState(order: detail));
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
      emit(ServiceOrderDetailState(order: detail, saving: true));
    }
    final result = await cancelInvoice(event.orderId, event.reason);
    _invoiceCancelling = false;
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(ServiceOrderDetailState(order: detail));
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
      emit(ServiceOrderDetailState(order: detail, saving: true));
    }
    final result = await invoice(event.orderId, event.input);
    await result.fold(
      (failure) async {
        emit(ServiceOrderActionFailure(failure));
        if (detail != null) emit(ServiceOrderDetailState(order: detail));
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
}
