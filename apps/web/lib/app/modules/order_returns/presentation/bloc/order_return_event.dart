part of 'order_return_bloc.dart';

sealed class OrderReturnEvent extends Equatable {
  const OrderReturnEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a lista da aba [status] ('A' abertas | 'F' faturadas) com o
/// [filter] de nome de cliente. Paginação: [page] navega (troca de
/// aba/filtro novo SEMPRE volta à página 1 — o default); [pageSize] null
/// mantém o tamanho corrente.
class OrderReturnListRequested extends OrderReturnEvent {
  const OrderReturnListRequested({
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

/// Abre a devolução ancorada no pedido de venda FATURADO [saleOrderId]
/// (itens pré-carregados pela API — 422 ORIGIN_NOT_INVOICED /
/// NOTHING_RETURNABLE viram dialog de validação, via one-shot).
class OrderReturnOpenRequested extends OrderReturnEvent {
  const OrderReturnOpenRequested(this.saleOrderId);
  final int saleOrderId;

  @override
  List<Object?> get props => [saleOrderId];
}

/// Tap na linha: carrega a devolução completa (GET /:id) e abre o detalhe.
class OrderReturnViewRequested extends OrderReturnEvent {
  const OrderReturnViewRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do detalhe para a lista (recarrega a aba atual).
class OrderReturnBackToListPressed extends OrderReturnEvent {
  const OrderReturnBackToListPressed();
}

/// Cancela a devolução ABERTA (confirmação já feita pela página).
class OrderReturnCancelRequested extends OrderReturnEvent {
  const OrderReturnCancelRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Altera a QUANTIDADE do item (único campo editável — teto maxQuantity;
/// o detalhe é recarregado, o total é recalculado no servidor).
class OrderReturnItemQuantityRequested extends OrderReturnEvent {
  const OrderReturnItemQuantityRequested({
    required this.returnId,
    required this.itemId,
    required this.quantity,
  });

  final int returnId;
  final int itemId;
  final double quantity;

  @override
  List<Object?> get props => [returnId, itemId, quantity];
}

/// Remove um item da devolução aberta (confirmação já feita pela página —
/// sem re-inclusão: removeu errado → cancela a devolução e reabre).
class OrderReturnItemRemoveRequested extends OrderReturnEvent {
  const OrderReturnItemRemoveRequested(
      {required this.returnId, required this.itemId});

  final int returnId;
  final int itemId;

  @override
  List<Object?> get props => [returnId, itemId];
}

/// Botão "Validar e Faturar" (CFOP já escolhido no dialog): dispara
/// validate com adjustment = { cfopId }; issues não vazio abre o dialog de
/// pendências (one-shot); issues vazio dispara invoice em seguida (evento
/// próprio, disparado pela página ao ver o resultado).
class OrderReturnBillingValidateRequested extends OrderReturnEvent {
  const OrderReturnBillingValidateRequested(
      {required this.returnId, required this.cfopId});

  final int returnId;
  final String cfopId;

  @override
  List<Object?> get props => [returnId, cfopId];
}

/// Fatura a devolução — só disparado pela página depois de um validate sem
/// issues (mesmo [cfopId]); sucesso volta pra lista na aba Faturadas.
class OrderReturnBillingInvoiceRequested extends OrderReturnEvent {
  const OrderReturnBillingInvoiceRequested(
      {required this.returnId, required this.cfopId});

  final int returnId;
  final String cfopId;

  @override
  List<Object?> get props => [returnId, cfopId];
}
