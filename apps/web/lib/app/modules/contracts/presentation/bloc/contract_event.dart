part of 'contract_bloc.dart';

sealed class ContractEvent extends Equatable {
  const ContractEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista ([refresh] força nova consulta; o filtro por
/// nome do cliente é LOCAL — a API já limita a 200, molde payment_types).
class ContractListRequested extends ContractEvent {
  const ContractListRequested(this.filter, {this.refresh = false});
  final String filter;
  final bool refresh;

  @override
  List<Object?> get props => [filter, refresh];
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
