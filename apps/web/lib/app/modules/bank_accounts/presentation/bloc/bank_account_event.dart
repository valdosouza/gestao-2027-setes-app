part of 'bank_account_bloc.dart';

sealed class BankAccountEvent extends Equatable {
  const BankAccountEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por banco/agência/conta/gerente é REMOTO (?filter= — D7). Paginação D3:
/// [page] navega (filtro novo SEMPRE volta à página 1 na tela); [pageSize]
/// null mantém o tamanho corrente (1º load = config page_size da API — D4).
class BankAccountListRequested extends BankAccountEvent {
  const BankAccountListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
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
