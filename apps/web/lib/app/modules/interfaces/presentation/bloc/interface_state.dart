part of 'interface_bloc.dart';

sealed class InterfaceState extends Equatable {
  const InterfaceState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class InterfaceListState extends InterfaceState {
  const InterfaceListState({this.items = const [], this.loading = false});
  final List<InterfaceEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class InterfaceFormState extends InterfaceState {
  const InterfaceFormState({this.editing, this.saving = false});
  final InterfaceEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class InterfaceActionSuccess extends InterfaceState {
  const InterfaceActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class InterfaceActionFailure extends InterfaceState {
  const InterfaceActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
