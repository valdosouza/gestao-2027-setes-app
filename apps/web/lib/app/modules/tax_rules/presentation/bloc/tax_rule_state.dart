part of 'tax_rule_bloc.dart';

sealed class TaxRuleState extends Equatable {
  const TaxRuleState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class TaxRuleListState extends TaxRuleState {
  const TaxRuleListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<TaxRuleListItem> items;
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

/// Modo formulário (buildável). O [draft] é a regra INTEIRA (seletor +
/// peças) — as abas editam fatias via TaxRuleDraftChanged. [catalogs] são
/// os combos fiscais, carregados UMA vez na abertura (cache do bloc).
class TaxRuleFormState extends TaxRuleState {
  const TaxRuleFormState({
    required this.draft,
    required this.creating,
    this.catalogs = const TaxRuleCatalogs(),
    this.saving = false,
  });

  final TaxRuleDraft draft;
  final bool creating;
  final TaxRuleCatalogs catalogs;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, catalogs, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class TaxRuleActionSuccess extends TaxRuleState {
  const TaxRuleActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo da aba certa.
class TaxRuleActionFailure extends TaxRuleState {
  const TaxRuleActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
