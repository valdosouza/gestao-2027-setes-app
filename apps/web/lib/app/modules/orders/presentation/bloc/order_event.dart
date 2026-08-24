part of 'order_bloc.dart';

sealed class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a lista da aba [status] ('A' abertos | 'F' faturados) com o
/// [filter] de nome de cliente. Paginação: [page] navega (troca de
/// aba/filtro novo SEMPRE volta à página 1 — o default); [pageSize] null
/// mantém o tamanho corrente.
class OrderListRequested extends OrderEvent {
  const OrderListRequested({
    this.status,
    this.filter,
    this.page = 1,
    this.pageSize,
  });

  /// null = mantém a aba atual do bloc.
  final String? status;

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [status, filter, page, pageSize];
}

/// FAB "Novo pedido": POST com cliente (obrigatório) e vendedor (opcional
/// — 400 SALESMAN_REQUIRED vira dialog de validação, via one-shot).
class OrderOpenRequested extends OrderEvent {
  const OrderOpenRequested({required this.customerId, this.salesmanId});

  final int customerId;
  final int? salesmanId;

  @override
  List<Object?> get props => [customerId, salesmanId];
}

/// Tap na linha: carrega o pedido completo (GET /:id) e abre o detalhe.
class OrderViewRequested extends OrderEvent {
  const OrderViewRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do detalhe para a lista (recarrega a aba atual).
class OrderBackToListPressed extends OrderEvent {
  const OrderBackToListPressed();
}

/// Cancela o pedido ABERTO (confirmação já feita pela página).
class OrderCancelRequested extends OrderEvent {
  const OrderCancelRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Inclui ([itemId] null) ou altera um item — o detalhe é recarregado (o
/// totalizer é recalculado no servidor).
class OrderItemSaveRequested extends OrderEvent {
  const OrderItemSaveRequested({
    required this.orderId,
    this.itemId,
    required this.input,
  });

  final int orderId;
  final int? itemId;
  final OrderItemInput input;

  @override
  List<Object?> get props => [orderId, itemId, input];
}

/// Remove um item do pedido aberto (confirmação já feita pela página).
class OrderItemRemoveRequested extends OrderEvent {
  const OrderItemRemoveRequested({required this.orderId, required this.itemId});

  final int orderId;
  final int itemId;

  @override
  List<Object?> get props => [orderId, itemId];
}

/// Botão "Validar e Faturar" — dispara validate; issues não vazio abre o
/// dialog de pendências (one-shot); issues vazio dispara invoice em
/// seguida (evento próprio, disparado pela página ao ver o resultado).
class OrderBillingValidateRequested extends OrderEvent {
  const OrderBillingValidateRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// Fatura o pedido — só disparado pela página depois de um validate sem
/// issues; sucesso volta pra lista na aba Faturados.
class OrderBillingInvoiceRequested extends OrderEvent {
  const OrderBillingInvoiceRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// Botão "Devolver" no detalhe do pedido FATURADO: abre a devolução
/// (POST /api/order-returns) — sucesso navega para o módulo order_returns
/// (one-shot [OrderReturnOpened]); 422 de negócio vira dialog com a
/// mensagem da API.
class OrderReturnRequested extends OrderEvent {
  const OrderReturnRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}
