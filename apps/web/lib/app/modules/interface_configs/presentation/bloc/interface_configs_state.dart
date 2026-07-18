part of 'interface_configs_bloc.dart';

sealed class InterfaceConfigsState extends Equatable {
  const InterfaceConfigsState();

  @override
  List<Object?> get props => [];
}

/// Vitrine de interfaces (buildável) — mostra TODAS, marcando adquiridas.
class InterfaceConfigsVitrineState extends InterfaceConfigsState {
  const InterfaceConfigsVitrineState({this.items = const [], this.loading = false});
  final List<InterfaceVitrineEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Configurações da interface aberta (buildável).
class InterfaceConfigsConfigsState extends InterfaceConfigsState {
  const InterfaceConfigsConfigsState({
    required this.iface,
    this.configs = const [],
    this.loading = false,
    this.saving = false,
  });

  final InterfaceVitrineEntity iface;
  final List<InterfaceConfigEntity> configs;
  final bool loading;
  final bool saving;

  @override
  List<Object?> get props => [iface, configs, loading, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only).
class InterfaceConfigsActionSuccess extends InterfaceConfigsState {
  const InterfaceConfigsActionSuccess(this.messageKey);
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only).
class InterfaceConfigsActionFailure extends InterfaceConfigsState {
  const InterfaceConfigsActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
