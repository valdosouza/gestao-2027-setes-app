part of 'country_bloc.dart';

sealed class CountryState extends Equatable {
  const CountryState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class CountryListState extends CountryState {
  const CountryListState({this.items = const [], this.loading = false});
  final List<CountryEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class CountryFormState extends CountryState {
  const CountryFormState({this.editing, this.saving = false});
  final CountryEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CountryActionSuccess extends CountryState {
  const CountryActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class CountryActionFailure extends CountryState {
  const CountryActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
