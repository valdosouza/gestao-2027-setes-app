part of 'service_tax_rule_bloc.dart';

sealed class ServiceTaxRuleEvent extends Equatable {
  const ServiceTaxRuleEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por cidade/item/descrição é REMOTO (?filter=). Paginação: [page] navega
/// (filtro novo SEMPRE volta à página 1 na tela); [pageSize] null mantém o
/// tamanho corrente (1º load = config page_size da API).
class ServiceTaxRuleListRequested extends ServiceTaxRuleEvent {
  const ServiceTaxRuleListRequested(this.filter,
      {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class ServiceTaxRuleNewPressed extends ServiceTaxRuleEvent {
  const ServiceTaxRuleNewPressed();
}

/// Abre a edição — o bloc recarrega a regra (GET /:id) antes de emitir o
/// form (fonte da verdade é a API).
class ServiceTaxRuleEditPressed extends ServiceTaxRuleEvent {
  const ServiceTaxRuleEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class ServiceTaxRuleBackToListPressed extends ServiceTaxRuleEvent {
  const ServiceTaxRuleBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT. [input] já validado
/// pela página (a API revalida via Zod — 400 {error, fields[]}).
class ServiceTaxRuleSaveRequested extends ServiceTaxRuleEvent {
  const ServiceTaxRuleSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final ServiceTaxRuleInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class ServiceTaxRuleDeleteRequested extends ServiceTaxRuleEvent {
  const ServiceTaxRuleDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
