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

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class PaymentTypeActionSuccess extends PaymentTypeState {
  const PaymentTypeActionSuccess(this.messageKey);

  /// Chave i18n — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class PaymentTypeActionFailure extends PaymentTypeState {
  const PaymentTypeActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
