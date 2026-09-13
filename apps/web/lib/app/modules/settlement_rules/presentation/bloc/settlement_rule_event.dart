part of 'settlement_rule_bloc.dart';

sealed class SettlementRuleEvent extends Equatable {
  const SettlementRuleEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por forma/conta é REMOTO (?filter=). [page] navega (filtro novo SEMPRE
/// volta à página 1 na tela); [pageSize] null mantém o tamanho corrente
/// (1º load = config page_size da API).
class SettlementRuleListRequested extends SettlementRuleEvent {
  const SettlementRuleListRequested(this.filter,
      {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class SettlementRuleNewPressed extends SettlementRuleEvent {
  const SettlementRuleNewPressed();
}

/// Abre a edição — o bloc carrega o contrato COMPLETO (GET /:id) antes de
/// emitir o form (a lista não traz a observação).
class SettlementRuleEditPressed extends SettlementRuleEvent {
  const SettlementRuleEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class SettlementRuleBackToListPressed extends SettlementRuleEvent {
  const SettlementRuleBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT (a forma não muda —
/// é a PK). [input] já validado pela página (a API revalida via Zod —
/// 400 {error, fields[]}; 409 FINANCIAL_CONTRACT_EXISTS em paymentTypeId).
class SettlementRuleSaveRequested extends SettlementRuleEvent {
  const SettlementRuleSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final SettlementRuleInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class SettlementRuleDeleteRequested extends SettlementRuleEvent {
  const SettlementRuleDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
