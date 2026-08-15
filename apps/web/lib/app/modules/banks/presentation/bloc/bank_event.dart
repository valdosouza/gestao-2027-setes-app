part of 'bank_bloc.dart';

sealed class BankEvent extends Equatable {
  const BankEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class BankListRequested extends BankEvent {
  const BankListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class BankNewPressed extends BankEvent {
  const BankNewPressed();
}

class BankEditPressed extends BankEvent {
  const BankEditPressed(this.bank);
  final BankEntity bank;

  @override
  List<Object?> get props => [bank];
}

/// Volta do formulário para a pesquisa SEM salvar.
class BankBackToListPressed extends BankEvent {
  const BankBackToListPressed();
}

class BankSaveRequested extends BankEvent {
  const BankSaveRequested({required this.bank, required this.creating});
  final BankEntity bank;
  final bool creating;

  @override
  List<Object?> get props => [bank, creating];
}

class BankDeleteRequested extends BankEvent {
  const BankDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
