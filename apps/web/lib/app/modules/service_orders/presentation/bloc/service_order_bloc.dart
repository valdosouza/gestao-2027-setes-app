import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/usecase/service_order_delete.dart';
import '../../domain/usecase/service_order_get.dart';
import '../../domain/usecase/service_order_getlist.dart';
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
  }

  final ServiceOrderGetlist getlist;
  final ServiceOrderGet get;
  final ServiceOrderPost post;
  final ServiceOrderDelete delete;
  final ServiceOrderItemSave itemSave;
  final ServiceOrderItemDelete itemDelete;
  final ServiceOrderMonthlyRun monthlyRun;
  final ServiceOrderInvoice invoice;

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
