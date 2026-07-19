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

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class StateActionSuccess extends StateBlocState {
  const StateActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class StateActionFailure extends StateBlocState {
  const StateActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
