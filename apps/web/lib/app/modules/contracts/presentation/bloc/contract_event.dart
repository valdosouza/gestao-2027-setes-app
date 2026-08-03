part of 'contract_bloc.dart';

sealed class ContractEvent extends Equatable {
  const ContractEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por nome do cliente é REMOTO (?filter= — D7). Paginação D3: [page]
/// navega (filtro novo SEMPRE volta à página 1 na tela); [pageSize] null
/// mantém o tamanho corrente (1º load = config page_size da API — D4).
class ContractListRequested extends ContractEvent {
  const ContractListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class ContractNewPressed extends ContractEvent {
  const ContractNewPressed();
}

/// Abre a edição — o bloc carrega o contrato COMPLETO (GET /:id) antes de
/// emitir o form (a lista não traz itens nem paymentDay).
class ContractEditPressed extends ContractEvent {
  const ContractEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class ContractBackToListPressed extends ContractEvent {
  const ContractBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT (a API sincroniza os
/// itens por productId). [input] já validado pela página.
class ContractSaveRequested extends ContractEvent {
  const ContractSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final ContractInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class ContractDeleteRequested extends ContractEvent {
  const ContractDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
