part of 'payment_type_bloc.dart';

sealed class PaymentTypeState extends Equatable {
  const PaymentTypeState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — formas VINCULADAS à institution.
class PaymentTypeListState extends PaymentTypeState {
  const PaymentTypeListState({this.items = const [], this.loading = false});
  final List<LinkedPaymentType> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
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
