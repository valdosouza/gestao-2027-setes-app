part of 'order_bloc.dart';

sealed class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — a aba ativa vem em [status] ('A'|'F').
/// Paginação: além dos itens da página, o estado carrega filtro aplicado
/// + metadados — a página monta a RegisterPagingBar no rodapé.
class OrderListState extends OrderState {
  const OrderListState({
    this.items = const [],
    this.loading = false,
    this.status = 'A',
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<OrderListItem> items;
  final bool loading;
  final String status;

  /// Filtro APLICADO (o mesmo usado nas recargas do bloc).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props =>
      [items, loading, status, filter, page, pageSize, total];
}

/// Modo detalhe do pedido (buildável). [saving] desabilita as ações
/// enquanto uma operação (item/cancelar/faturar) está em andamento.
class OrderDetailState extends OrderState {
  const OrderDetailState({required this.order, this.saving = false});

  final OrderFull order;
  final bool saving;

  @override
  List<Object?> get props => [order, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave.
class OrderActionSuccess extends OrderState {
  const OrderActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO — a ponte deriva a natureza; os 409/400 de negócio
/// (SALESMAN_REQUIRED, ORDER_INVOICED) viram dialog de validação com a
/// mensagem da API.
class OrderActionFailure extends OrderState {
  const OrderActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Resultado do POST /api/billing/validate (one-shot) — a página decide:
/// issues vazio dispara o invoice em seguida; issues presentes abrem o
/// dialog de pendências.
class OrderBillingValidated extends OrderState {
  const OrderBillingValidated(this.result);
  final OrderBillingValidation result;

  @override
  List<Object?> get props => [result];
}

/// Faturamento concluído (one-shot) — a página mostra o nº da fatura e a
/// lista recarrega na aba Faturados.
class OrderBillingInvoiced extends OrderState {
  const OrderBillingInvoiced(this.result);
  final OrderBillingInvoice result;

  @override
  List<Object?> get props => [result];
}

/// Devolução aberta a partir do pedido faturado (one-shot) — a página
/// navega para o módulo order_returns, onde a devolução recém-criada
/// aparece no topo da aba Abertas.
class OrderReturnOpened extends OrderState {
  const OrderReturnOpened(this.returnId);
  final int returnId;

  @override
  List<Object?> get props => [returnId];
}
