part of 'settlement_rule_bloc.dart';

sealed class SettlementRuleState extends Equatable {
  const SettlementRuleState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — regras de recebimento da institution. Além dos
/// itens da página, o estado carrega filtro aplicado + metadados — a
/// página monta a barra de paginação da fábrica e reenvia [filter].
class SettlementRuleListState extends SettlementRuleState {
  const SettlementRuleListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<SettlementRuleListItem> items;
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

/// Modo formulário (buildável). [editing] null = contrato novo.
class SettlementRuleFormState extends SettlementRuleState {
  const SettlementRuleFormState({this.editing, this.saving = false});
  final SettlementRuleFull? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class SettlementRuleActionSuccess extends SettlementRuleState {
  const SettlementRuleActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico — R7) e o fields[]
/// ancora no campo do formulário.
class SettlementRuleActionFailure extends SettlementRuleState {
  const SettlementRuleActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
