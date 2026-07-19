part of 'bank_account_bloc.dart';

sealed class BankAccountEvent extends Equatable {
  const BankAccountEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista ([refresh] força nova consulta; o filtro por
/// banco/agência/conta/gerente é LOCAL — a API já limita a 200, molde
/// contracts/payment_types).
class BankAccountListRequested extends BankAccountEvent {
  const BankAccountListRequested(this.filter, {this.refresh = false});
  final String filter;
  final bool refresh;

  @override
  List<Object?> get props => [filter, refresh];
}

class BankAccountNewPressed extends BankAccountEvent {
  const BankAccountNewPressed();
}

/// Abre a edição — o bloc carrega a conta COMPLETA (GET /:id) antes de
/// emitir o form (a lista não traz datas nem telefone).
class BankAccountEditPressed extends BankAccountEvent {
  const BankAccountEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class BankAccountBackToListPressed extends BankAccountEvent {
  const BankAccountBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT. [input] já validado
/// pela página (a API revalida via Zod — 400 {error, fields[]}).
class BankAccountSaveRequested extends BankAccountEvent {
  const BankAccountSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final BankAccountInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class BankAccountDeleteRequested extends BankAccountEvent {
  const BankAccountDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
