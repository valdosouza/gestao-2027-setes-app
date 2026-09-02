part of 'service_bloc.dart';

sealed class ServiceState extends Equatable {
  const ServiceState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — serviços da institution, uma página por vez:
/// além dos itens, o estado carrega filtro aplicado + metadados — a página
/// monta a barra da fábrica e reenvia [filter] ao navegar.
class ServiceListState extends ServiceState {
  const ServiceListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<ServiceListItem> items;
  final bool loading;

  /// Filtro APLICADO (o mesmo usado na recarga pós-salvar/excluir).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, filter, page, pageSize, total];
}

/// Modo formulário (buildável). [editing] null = serviço novo; [prices] é
/// a grade INICIAL da aba Preços (do GET /:id na edição; das tabelas de
/// preço vivas, sem valor, no novo).
class ServiceFormState extends ServiceState {
  const ServiceFormState({
    this.editing,
    this.prices = const [],
    this.saving = false,
  });

  final ServiceFull? editing;
  final List<ServicePrice> prices;
  final bool saving;

  @override
  List<Object?> get props => [editing, prices, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class ServiceActionSuccess extends ServiceState {
  const ServiceActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico com supportRef —
/// R7) e o fields[] ancora no campo do formulário.
class ServiceActionFailure extends ServiceState {
  const ServiceActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
