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

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class BankAccountActionSuccess extends BankAccountState {
  const BankAccountActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class BankAccountActionFailure extends BankAccountState {
  const BankAccountActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
