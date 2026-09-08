part of 'financial_contract_bloc.dart';

sealed class FinancialContractEvent extends Equatable {
  const FinancialContractEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por forma/conta é REMOTO (?filter=). [page] navega (filtro novo SEMPRE
/// volta à página 1 na tela); [pageSize] null mantém o tamanho corrente
/// (1º load = config page_size da API).
class FinancialContractListRequested extends FinancialContractEvent {
  const FinancialContractListRequested(this.filter,
      {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class FinancialContractNewPressed extends FinancialContractEvent {
  const FinancialContractNewPressed();
}

/// Abre a edição — o bloc carrega o contrato COMPLETO (GET /:id) antes de
/// emitir o form (a lista não traz a observação).
class FinancialContractEditPressed extends FinancialContractEvent {
  const FinancialContractEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class FinancialContractBackToListPressed extends FinancialContractEvent {
  const FinancialContractBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT (a forma não muda —
/// é a PK). [input] já validado pela página (a API revalida via Zod —
/// 400 {error, fields[]}; 409 FINANCIAL_CONTRACT_EXISTS em paymentTypeId).
class FinancialContractSaveRequested extends FinancialContractEvent {
  const FinancialContractSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final FinancialContractInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class FinancialContractDeleteRequested extends FinancialContractEvent {
  const FinancialContractDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
