import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/order_entity.dart';
import '../../domain/usecase/order_billing_invoice.dart';
import '../../domain/usecase/order_billing_validate.dart';
import '../../domain/usecase/order_delete.dart';
import '../../domain/usecase/order_get.dart';
import '../../domain/usecase/order_getlist.dart';
import '../../domain/usecase/order_item_delete.dart';
import '../../domain/usecase/order_item_save.dart';
import '../../domain/usecase/order_post.dart';
import '../../domain/usecase/order_return_open.dart';

part 'order_event.dart';
part 'order_state.dart';

/// Orquestra o Pedido de Venda/Conjugado — TELA DE PROCESSO (molde
/// service_orders): lista em abas Abertos × Faturados ↔ detalhe do
/// pedido. Toda operação (abrir, item, cancelar, faturar) chama a API e
/// RECARREGA — o totalizer e o status vivem no servidor. Faturamento é
/// duas chamadas (validate → invoice) ao módulo billing, direto pela API
/// (sem módulo billing próprio no app). Falhas carregam o [Failure]
/// INTEIRO no one-shot (Framework de Mensagens): a página entrega à
/// PONTE, que deriva o canal.
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  OrderBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.delete,
    required this.itemSave,
    required this.itemDelete,
    required this.billingValidate,
    required this.billingInvoice,
    required this.returnOpen,
  }) : super(const OrderListState(loading: true)) {
    on<OrderListRequested>(_onListRequested);
    on<OrderOpenRequested>(_onOpenRequested);
    on<OrderViewRequested>(_onViewRequested);
    on<OrderBackToListPressed>((event, emit) => _reloadList(emit));
    on<OrderCancelRequested>(_onCancelRequested);
    on<OrderItemSaveRequested>(_onItemSaveRequested);
    on<OrderItemRemoveRequested>(_onItemRemoveRequested);
    on<OrderBillingValidateRequested>(_onBillingValidateRequested);
    on<OrderBillingInvoiceRequested>(_onBillingInvoiceRequested);
    on<OrderReturnRequested>(_onReturnRequested);
  }

  final OrderGetlist getlist;
  final OrderGet get;
  final OrderPost post;
  final OrderDelete delete;
  final OrderItemSave itemSave;
  final OrderItemDelete itemDelete;
  final OrderBillingValidate billingValidate;
  final OrderBillingInvoiceUsecase billingInvoice;
  final OrderReturnOpen returnOpen;

  /// Abertura de devolução em voo (guard de duplo-clique — R5 do gate).
  bool _returnOpening = false;

  /// Aba ativa ('A' abertos | 'F' faturados) e filtro atual da lista.
  String _status = 'A';
  String _filter = '';

  /// Última página/tamanho aplicados — recarga após operação devolve o
  /// usuário exatamente onde estava.
  int _page = 1;
  int? _pageSize;

  /// Pedido aberto no detalhe — preserva o conteúdo nos re-emits de
  /// saving/falha sem nova consulta.
  OrderFull? _detail;

  Future<void> _reloadList(Emitter<OrderState> emit) async {
    _detail = null;
    emit(OrderListState(loading: true, status: _status));
    final result =
        await getlist(_status, _filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        emit(OrderListState(status: _status));
      },
      (paged) async {
        // Página esvaziou (ex.: faturamento tirou o último item da aba) →
        // recua para a última página existente em vez de lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reloadList(emit);
        }
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(OrderListState(
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
  Future<void> _reloadDetail(int id, Emitter<OrderState> emit) async {
    final result = await get(id);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        await _reloadList(emit);
      },
      (full) async {
        _detail = full;
        emit(OrderDetailState(order: full));
      },
    );
  }

  Future<void> _onListRequested(
      OrderListRequested event, Emitter<OrderState> emit) async {
    _status = event.status ?? _status;
    _filter = event.filter ?? _filter;
    // Troca de aba/filtro SEMPRE volta à página 1 (default do evento); só
    // a navegação da barra manda outra página.
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reloadList(emit);
  }

  Future<void> _onOpenRequested(
      OrderOpenRequested event, Emitter<OrderState> emit) async {
    emit(OrderListState(loading: true, status: _status));
    final result = await post(event.customerId, event.salesmanId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        await _reloadList(emit);
      },
      (id) async {
        emit(const OrderActionSuccess('forms.order.opened'));
        await _reloadDetail(id, emit);
      },
    );
  }

  Future<void> _onViewRequested(
      OrderViewRequested event, Emitter<OrderState> emit) async {
    emit(OrderListState(loading: true, status: _status));
    await _reloadDetail(event.id, emit);
  }

  Future<void> _onCancelRequested(
      OrderCancelRequested event, Emitter<OrderState> emit) async {
    final detail = _detail;
    if (detail != null) emit(OrderDetailState(order: detail, saving: true));
    final result = await delete(event.id);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
      (_) async {
        emit(const OrderActionSuccess('forms.order.canceled'));
        await _reloadList(emit);
      },
    );
  }

  Future<void> _onItemSaveRequested(
      OrderItemSaveRequested event, Emitter<OrderState> emit) async {
    final detail = _detail;
    if (detail != null) emit(OrderDetailState(order: detail, saving: true));
    final result = await itemSave(event.orderId, event.itemId, event.input);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
      (_) async {
        emit(const OrderActionSuccess('register.saved'));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  Future<void> _onItemRemoveRequested(
      OrderItemRemoveRequested event, Emitter<OrderState> emit) async {
    final detail = _detail;
    if (detail != null) emit(OrderDetailState(order: detail, saving: true));
    final result = await itemDelete(event.orderId, event.itemId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
      (_) async {
        emit(const OrderActionSuccess('register.deleted'));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  Future<void> _onBillingValidateRequested(
      OrderBillingValidateRequested event, Emitter<OrderState> emit) async {
    final detail = _detail;
    if (detail != null) emit(OrderDetailState(order: detail, saving: true));
    final result = await billingValidate(event.orderId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
      (validation) async {
        emit(OrderBillingValidated(validation));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
    );
  }

  Future<void> _onBillingInvoiceRequested(
      OrderBillingInvoiceRequested event, Emitter<OrderState> emit) async {
    final detail = _detail;
    if (detail != null) emit(OrderDetailState(order: detail, saving: true));
    final result = await billingInvoice(event.orderId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
      (invoiceResult) async {
        emit(OrderBillingInvoiced(invoiceResult));
        // Fluxo do processo: o pedido faturado aparece na aba Faturados —
        // troca de aba SEMPRE volta à página 1.
        _status = 'F';
        _page = 1;
        await _reloadList(emit);
      },
    );
  }

  /// Ação "Devolver" do pedido FATURADO: abre a devolução na API e emite o
  /// one-shot [OrderReturnOpened] — quem navega para o módulo
  /// order_returns é a página (módulo nunca importa módulo).
  Future<void> _onReturnRequested(
      OrderReturnRequested event, Emitter<OrderState> emit) async {
    // R5 do gate socrático 2026-08-24: duplo-clique enfileira 2 eventos
    // antes do rebuild desabilitar o botão — o guard mata o segundo (duas
    // devoluções nasceriam com o saldo cheio; acidente ≠ irmã intencional).
    if (_returnOpening) return;
    _returnOpening = true;
    final detail = _detail;
    if (detail != null) emit(OrderDetailState(order: detail, saving: true));
    final result = await returnOpen(event.orderId);
    _returnOpening = false;
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
      (returnId) async {
        emit(OrderReturnOpened(returnId));
        if (detail != null) emit(OrderDetailState(order: detail));
      },
    );
  }
}
