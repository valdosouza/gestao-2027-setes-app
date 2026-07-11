part of 'state_bloc.dart';

sealed class StateBlocState extends Equatable {
  const StateBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class StateListState extends StateBlocState {
  const StateListState({this.items = const [], this.loading = false});
  final List<StateEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class StateFormState extends StateBlocState {
  const StateFormState({this.editing, this.saving = false});
  final StateEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class StateActionSuccess extends StateBlocState {
  const StateActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class StateActionFailure extends StateBlocState {
  const StateActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
