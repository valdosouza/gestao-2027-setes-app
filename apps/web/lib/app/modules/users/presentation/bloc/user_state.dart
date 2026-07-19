part of 'user_bloc.dart';

sealed class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class UserListState extends UserState {
  const UserListState({this.items = const [], this.loading = false});
  final List<UserListItem> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class UserFormState extends UserState {
  const UserFormState({this.editing, this.saving = false});
  final UserEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class UserActionSuccess extends UserState {
  const UserActionSuccess(this.messageKey);
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico com supportRef —
/// R7) e o fields[] ancora no campo do formulário.
class UserActionFailure extends UserState {
  const UserActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
