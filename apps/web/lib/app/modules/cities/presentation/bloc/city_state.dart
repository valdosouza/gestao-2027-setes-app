part of 'city_bloc.dart';

sealed class CityState extends Equatable {
  const CityState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class CityListState extends CityState {
  const CityListState({this.items = const [], this.loading = false});
  final List<CityEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão.
class CityFormState extends CityState {
  const CityFormState({this.editing, this.saving = false});
  final CityEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class CityActionSuccess extends CityState {
  const CityActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class CityActionFailure extends CityState {
  const CityActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
