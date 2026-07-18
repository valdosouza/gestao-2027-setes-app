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

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class CfopActionSuccess extends CfopState {
  const CfopActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class CfopActionFailure extends CfopState {
  const CfopActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
