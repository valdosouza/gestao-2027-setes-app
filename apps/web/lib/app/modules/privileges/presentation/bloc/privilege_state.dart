part of 'privilege_bloc.dart';

sealed class PrivilegeState extends Equatable {
  const PrivilegeState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class PrivilegeListState extends PrivilegeState {
  const PrivilegeListState({this.items = const [], this.loading = false});
  final List<PrivilegeEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class PrivilegeFormState extends PrivilegeState {
  const PrivilegeFormState({this.editing, this.saving = false});
  final PrivilegeEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class PrivilegeActionSuccess extends PrivilegeState {
  const PrivilegeActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class PrivilegeActionFailure extends PrivilegeState {
  const PrivilegeActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
