part of 'order_return_bloc.dart';

sealed class OrderReturnState extends Equatable {
  const OrderReturnState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — a aba ativa vem em [status] ('A'|'F').
/// Paginação: além dos itens da página, o estado carrega filtro aplicado
/// + metadados — a página monta a RegisterPagingBar no rodapé.
class OrderReturnListState extends OrderReturnState {
  const OrderReturnListState({
    this.items = const [],
    this.loading = false,
    this.status = 'A',
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<OrderReturnListItem> items;
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

/// Modo detalhe da devolução (buildável). [saving] desabilita as ações
/// enquanto uma operação (quantidade/remoção/cancelar/faturar) está em
/// andamento.
class OrderReturnDetailState extends OrderReturnState {
  const OrderReturnDetailState({required this.orderReturn, this.saving = false});

  final OrderReturnFull orderReturn;
  final bool saving;

  @override
  List<Object?> get props => [orderReturn, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave.
class OrderReturnActionSuccess extends OrderReturnState {
  const OrderReturnActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO — a ponte deriva a natureza; os 422/409 de negócio
/// (RETURN_INVALID, ORDER_INVOICED, ORIGIN_NOT_INVOICED,
/// NOTHING_RETURNABLE) viram dialog de validação com a mensagem da API.
class OrderReturnActionFailure extends OrderReturnState {
  const OrderReturnActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Resultado do POST /api/billing/validate (one-shot) — a página decide:
/// issues vazio dispara o invoice em seguida (com o MESMO [cfopId]);
/// issues presentes abrem o dialog de pendências.
class OrderReturnBillingValidated extends OrderReturnState {
  const OrderReturnBillingValidated(this.result, this.cfopId);

  final OrderReturnBillingValidation result;

  /// CFOP escolhido no dialog — a página o repassa ao invoice.
  final String cfopId;

  @override
  List<Object?> get props => [result, cfopId];
}

/// Faturamento concluído (one-shot) — a página mostra o nº da fatura e a
/// lista recarrega na aba Faturadas.
class OrderReturnBillingInvoiced extends OrderReturnState {
  const OrderReturnBillingInvoiced(this.result);
  final OrderReturnBillingInvoice result;

  @override
  List<Object?> get props => [result];
}
