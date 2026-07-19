part of 'service_order_bloc.dart';

sealed class ServiceOrderEvent extends Equatable {
  const ServiceOrderEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a lista da aba [status] ('A' abertas | 'F' faturadas) com o
/// [filter] de nome de cliente — a consulta é SEMPRE da API (tela de
/// processo: o status muda no servidor).
class ServiceOrderListRequested extends ServiceOrderEvent {
  const ServiceOrderListRequested({this.status, this.filter});

  /// null = mantém a aba atual do bloc.
  final String? status;

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  @override
  List<Object?> get props => [status, filter];
}

/// FAB "Abrir OS": POST com o cliente escolhido no lookup — 409 (cliente
/// já tem ordem aberta) vira dialog de validação com a mensagem da API,
/// via ponte; sucesso abre o detalhe da OS nova.
class ServiceOrderOpenRequested extends ServiceOrderEvent {
  const ServiceOrderOpenRequested(this.customerId);
  final int customerId;

  @override
  List<Object?> get props => [customerId];
}

/// Tap na linha: carrega a OS completa (GET /:id) e abre o detalhe.
class ServiceOrderViewRequested extends ServiceOrderEvent {
  const ServiceOrderViewRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do detalhe para a lista (recarrega a aba atual).
class ServiceOrderBackToListPressed extends ServiceOrderEvent {
  const ServiceOrderBackToListPressed();
}

/// Cancela a OS ABERTA (DELETE — confirmação já feita pela página).
class ServiceOrderCancelRequested extends ServiceOrderEvent {
  const ServiceOrderCancelRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Inclui ([itemId] null) ou altera um item — o detalhe é recarregado
/// (o totalizer é recalculado no servidor).
class ServiceOrderItemSaveRequested extends ServiceOrderEvent {
  const ServiceOrderItemSaveRequested({
    required this.orderId,
    this.itemId,
    required this.input,
  });

  final int orderId;
  final int? itemId;
  final ServiceOrderItemInput input;

  @override
  List<Object?> get props => [orderId, itemId, input];
}

/// Remove um item da OS aberta (confirmação já feita pela página).
class ServiceOrderItemRemoveRequested extends ServiceOrderEvent {
  const ServiceOrderItemRemoveRequested({
    required this.orderId,
    required this.itemId,
  });

  final int orderId;
  final int itemId;

  @override
  List<Object?> get props => [orderId, itemId];
}

/// Rotina Mensal (D8): POST /monthly-run — o relatório volta no one-shot
/// [ServiceOrderMonthlyRunDone] e a lista é recarregada.
class ServiceOrderMonthlyRunRequested extends ServiceOrderEvent {
  const ServiceOrderMonthlyRunRequested({
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  List<Object?> get props => [year, month];
}

/// Gerar Faturamento da OS aberta — sucesso mostra o nº da fatura e volta
/// para a lista na aba Faturadas.
class ServiceOrderInvoiceRequested extends ServiceOrderEvent {
  const ServiceOrderInvoiceRequested({
    required this.orderId,
    required this.input,
  });

  final int orderId;
  final ServiceOrderInvoiceInput input;

  @override
  List<Object?> get props => [orderId, input];
}
