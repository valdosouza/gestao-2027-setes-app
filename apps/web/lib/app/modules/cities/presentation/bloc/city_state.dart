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

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CityActionSuccess extends CityState {
  const CityActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class CityActionFailure extends CityState {
  const CityActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
