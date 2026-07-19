part of 'cfop_bloc.dart';

sealed class CfopState extends Equatable {
  const CfopState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class CfopListState extends CfopState {
  const CfopListState({this.items = const [], this.loading = false});
  final List<CfopEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class CfopFormState extends CfopState {
  const CfopFormState({this.editing, this.saving = false});
  final CfopEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CfopActionSuccess extends CfopState {
  const CfopActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class CfopActionFailure extends CfopState {
  const CfopActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
