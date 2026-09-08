part of 'bank_charge_agreement_bloc.dart';

sealed class BankChargeAgreementEvent extends Equatable {
  const BankChargeAgreementEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por convênio/banco é REMOTO (?filter=). [page] navega (filtro novo
/// SEMPRE volta à página 1 na tela); [pageSize] null mantém o tamanho
/// corrente (1º load = config page_size da API).
class BankChargeAgreementListRequested extends BankChargeAgreementEvent {
  const BankChargeAgreementListRequested(this.filter,
      {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class BankChargeAgreementNewPressed extends BankChargeAgreementEvent {
  const BankChargeAgreementNewPressed();
}

/// Abre a edição — o bloc carrega a carteira COMPLETA (GET /:id) antes de
/// emitir o form (a lista não traz encargos/instrução/protesto).
class BankChargeAgreementEditPressed extends BankChargeAgreementEvent {
  const BankChargeAgreementEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class BankChargeAgreementBackToListPressed extends BankChargeAgreementEvent {
  const BankChargeAgreementBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT. [input] já validado
/// pela página (a API revalida via Zod — 400 {error, fields[]}).
class BankChargeAgreementSaveRequested extends BankChargeAgreementEvent {
  const BankChargeAgreementSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final BankChargeAgreementInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class BankChargeAgreementDeleteRequested extends BankChargeAgreementEvent {
  const BankChargeAgreementDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
