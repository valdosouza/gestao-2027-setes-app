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
/// enquanto uma operação (item/cancelar/negociar/faturar) está em
/// andamento. [negotiation] é carregada JUNTO com o detalhe (GET
/// /:id/negotiation) — null = a leitura falhou (a seção oferece
/// "recarregar"); recarregada a cada operação de item (a base muda).
class OrderDetailState extends OrderState {
  const OrderDetailState({
    required this.order,
    this.negotiation,
    this.saving = false,
  });

  final OrderFull order;
  final OrderNegotiation? negotiation;
  final bool saving;

  @override
  List<Object?> get props => [order, negotiation, saving];
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
/// issues presentes abrem o dialog de pendências; issues vazio → se
/// alguma parcela da [negotiation] (RELIDA após a validação — nunca a
/// grade velha) é cheque, abre o dialog de cheques (D5) e só então
/// dispara o invoice com `checks`; senão dispara o invoice direto.
class OrderBillingValidated extends OrderState {
  const OrderBillingValidated(this.result, {this.negotiation});
  final OrderBillingValidation result;

  /// null quando há issues (não foi relida) — o fluxo não fatura.
  final OrderNegotiation? negotiation;

  @override
  List<Object?> get props => [result, negotiation];
}

/// Falha do POST /api/billing/invoice (one-shot). Carrega os [checks]
/// enviados: em 422 CHECK_SUM_MISMATCH/CHECK_REQUIRED a página mostra a
/// mensagem da API e REABRE o dialog com os cheques digitados (a 1ª
/// parcela pode absorver a diferença de impostos da nota — D7).
class OrderBillingInvoiceFailure extends OrderState {
  const OrderBillingInvoiceFailure(this.failure, {this.checks = const []});
  final Failure failure;
  final List<OrderParcelChecksInput> checks;

  @override
  List<Object?> get props => [failure, checks];
}

/// Falha do PUT /:id/negotiation (one-shot) — a seção de negociação ancora
/// o `fields[]` (deadline / paymentTypeId / installments[.i.campo]) no
/// campo certo; sem fields[] cai na ponte genérica.
class OrderNegotiationFailure extends OrderState {
  const OrderNegotiationFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
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

/// One-shot: nota cancelada (a lista volta em Abertos — D5).
class OrderInvoiceCancelled extends OrderState {
  const OrderInvoiceCancelled(this.result);
  final OrderBillingCancel result;
  @override
  List<Object?> get props => [result];
}

/// One-shot: cancelamento recusado — 409 INVOICE_CANCEL_BLOCKED traz
/// fields[] tipado (o que resolver antes); demais falhas, mensagem da API.
class OrderInvoiceCancelFailure extends OrderState {
  const OrderInvoiceCancelFailure(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}
