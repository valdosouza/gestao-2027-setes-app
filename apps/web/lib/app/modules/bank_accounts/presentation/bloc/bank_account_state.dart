part of 'bank_account_bloc.dart';

sealed class BankAccountState extends Equatable {
  const BankAccountState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — contas bancárias da institution.
class BankAccountListState extends BankAccountState {
  const BankAccountListState({this.items = const [], this.loading = false});
  final List<BankAccountListItem> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = conta nova.
class BankAccountFormState extends BankAccountState {
  const BankAccountFormState({this.editing, this.saving = false});
  final BankAccountFull? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class BankAccountActionSuccess extends BankAccountState {
  const BankAccountActionSuccess(this.messageKey);

  /// Chave i18n — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class BankAccountActionFailure extends BankAccountState {
  const BankAccountActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
