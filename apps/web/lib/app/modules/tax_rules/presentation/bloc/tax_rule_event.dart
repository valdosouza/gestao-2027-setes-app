part of 'tax_rule_bloc.dart';

sealed class TaxRuleEvent extends Equatable {
  const TaxRuleEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class TaxRuleListRequested extends TaxRuleEvent {
  const TaxRuleListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Novo registro: o bloc garante os catálogos dos combos antes de abrir o
/// form (GET /catalogs uma vez, cacheado).
class TaxRuleNewPressed extends TaxRuleEvent {
  const TaxRuleNewPressed();
}

/// Edição: busca a regra COMPLETA (GET :id) + catálogos antes de abrir.
/// Carrega o item da LISTA porque o GET :id não devolve o nome do estado
/// (exibição do lookup).
class TaxRuleEditPressed extends TaxRuleEvent {
  const TaxRuleEditPressed(this.item);
  final TaxRuleListItem item;

  @override
  List<Object?> get props => [item];
}

/// As abas editam fatias do draft — o bloc reemite o form atualizado.
class TaxRuleDraftChanged extends TaxRuleEvent {
  const TaxRuleDraftChanged(this.draft);
  final TaxRuleDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// Volta do formulário para a pesquisa SEM salvar.
class TaxRuleBackToListPressed extends TaxRuleEvent {
  const TaxRuleBackToListPressed();
}

class TaxRuleSaveRequested extends TaxRuleEvent {
  const TaxRuleSaveRequested({required this.draft, required this.creating});
  final TaxRuleDraft draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class TaxRuleDeleteRequested extends TaxRuleEvent {
  const TaxRuleDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
