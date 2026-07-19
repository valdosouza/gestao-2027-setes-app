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

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class PrivilegeActionSuccess extends PrivilegeState {
  const PrivilegeActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class PrivilegeActionFailure extends PrivilegeState {
  const PrivilegeActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
