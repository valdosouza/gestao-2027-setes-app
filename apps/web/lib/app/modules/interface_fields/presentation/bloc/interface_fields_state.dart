part of 'interface_fields_bloc.dart';

sealed class InterfaceFieldsState extends Equatable {
  const InterfaceFieldsState();

  @override
  List<Object?> get props => [];
}

/// Vitrine de interfaces (buildável) — decisão 6: mostra TODAS.
class InterfaceFieldsVitrineState extends InterfaceFieldsState {
  const InterfaceFieldsVitrineState({this.items = const [], this.loading = false});
  final List<InterfaceVitrineEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Campos da interface aberta (buildável).
class InterfaceFieldsFieldsState extends InterfaceFieldsState {
  const InterfaceFieldsFieldsState({
    required this.iface,
    this.fields = const [],
    this.loading = false,
    this.saving = false,
  });

  final InterfaceVitrineEntity iface;
  final List<FieldConfigEntity> fields;
  final bool loading;
  final bool saving;

  @override
  List<Object?> get props => [iface, fields, loading, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class InterfaceFieldsActionSuccess extends InterfaceFieldsState {
  const InterfaceFieldsActionSuccess(this.messageKey);
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico com supportRef — R7).
class InterfaceFieldsActionFailure extends InterfaceFieldsState {
  const InterfaceFieldsActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
