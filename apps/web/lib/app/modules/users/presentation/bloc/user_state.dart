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

/// Efeito one-shot para SnackBar de sucesso (listener-only).
class UserActionSuccess extends UserState {
  const UserActionSuccess(this.messageKey);
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only).
class UserActionFailure extends UserState {
  const UserActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
