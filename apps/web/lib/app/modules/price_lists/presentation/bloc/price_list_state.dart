part of 'price_list_bloc.dart';

sealed class PriceListState extends Equatable {
  const PriceListState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — tabelas de preço da institution, uma página por
/// vez: além dos itens, o estado carrega filtro aplicado + metadados — a
/// página monta a barra da fábrica e reenvia [filter] ao navegar.
class PriceListListState extends PriceListState {
  const PriceListListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<PriceListEntity> items;
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

/// Modo formulário (buildável). [editing] null = tabela nova.
class PriceListFormState extends PriceListState {
  const PriceListFormState({this.editing, this.saving = false});
  final PriceListEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class PriceListActionSuccess extends PriceListState {
  const PriceListActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico com supportRef —
/// R7) e o fields[] ancora no campo do formulário.
class PriceListActionFailure extends PriceListState {
  const PriceListActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
