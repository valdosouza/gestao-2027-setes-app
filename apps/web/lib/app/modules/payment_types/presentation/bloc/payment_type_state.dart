part of 'payment_type_bloc.dart';

sealed class PaymentTypeState extends Equatable {
  const PaymentTypeState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — formas VINCULADAS à institution. Paginação D3:
/// além dos itens da página, o estado carrega filtro aplicado + metadados —
/// a página monta a barra da fábrica e reenvia [filter] ao navegar.
class PaymentTypeListState extends PaymentTypeState {
  const PaymentTypeListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<LinkedPaymentType> items;
  final bool loading;

  /// Filtro APLICADO (o mesmo usado na recarga pós-salvar/excluir).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, filter, page, pageSize, total];
}

/// Modo formulário (buildável). [editing] null = novo vínculo.
class PaymentTypeFormState extends PaymentTypeState {
  const PaymentTypeFormState({this.editing, this.saving = false});
  final LinkedPaymentType? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class PaymentTypeActionSuccess extends PaymentTypeState {
  const PaymentTypeActionSuccess(this.messageKey);

  /// Chave i18n — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class PaymentTypeActionFailure extends PaymentTypeState {
  const PaymentTypeActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
