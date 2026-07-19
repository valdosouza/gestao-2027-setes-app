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

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class InterfaceActionSuccess extends InterfaceState {
  const InterfaceActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class InterfaceActionFailure extends InterfaceState {
  const InterfaceActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
