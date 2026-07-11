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

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class CountryActionSuccess extends CountryState {
  const CountryActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class CountryActionFailure extends CountryState {
  const CountryActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
