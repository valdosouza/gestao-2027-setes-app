part of 'interface_configs_bloc.dart';

sealed class InterfaceConfigsState extends Equatable {
  const InterfaceConfigsState();

  @override
  List<Object?> get props => [];
}

/// Vitrine de interfaces (buildável) — mostra TODAS, marcando adquiridas.
/// Paginação D3: além dos itens da página, o estado carrega filtro aplicado
/// + metadados — a página monta a barra da fábrica e reenvia [filter] ao
/// navegar.
class InterfaceConfigsVitrineState extends InterfaceConfigsState {
  const InterfaceConfigsVitrineState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<InterfaceVitrineEntity> items;
  final bool loading;

  /// Filtro APLICADO (o mesmo usado na recarga ao voltar da lista de configs).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, filter, page, pageSize, total];
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

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class InterfaceConfigsActionSuccess extends InterfaceConfigsState {
  const InterfaceConfigsActionSuccess(this.messageKey);
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico com supportRef — R7).
class InterfaceConfigsActionFailure extends InterfaceConfigsState {
  const InterfaceConfigsActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
