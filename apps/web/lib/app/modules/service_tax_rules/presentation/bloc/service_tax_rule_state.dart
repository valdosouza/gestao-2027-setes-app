part of 'service_tax_rule_bloc.dart';

sealed class ServiceTaxRuleState extends Equatable {
  const ServiceTaxRuleState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — regras da institution. Paginação: além dos
/// itens da página, o estado carrega filtro aplicado + metadados — a página
/// monta a barra da fábrica e reenvia [filter] ao navegar.
class ServiceTaxRuleListState extends ServiceTaxRuleState {
  const ServiceTaxRuleListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<ServiceTaxRuleEntity> items;
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

/// Modo formulário (buildável). [editing] null = regra nova.
class ServiceTaxRuleFormState extends ServiceTaxRuleState {
  const ServiceTaxRuleFormState({this.editing, this.saving = false});
  final ServiceTaxRuleEntity? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class ServiceTaxRuleActionSuccess extends ServiceTaxRuleState {
  const ServiceTaxRuleActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico com supportRef —
/// R7) e o fields[] ancora no campo do formulário.
class ServiceTaxRuleActionFailure extends ServiceTaxRuleState {
  const ServiceTaxRuleActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
