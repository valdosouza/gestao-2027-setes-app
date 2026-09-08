part of 'bank_slip_bloc.dart';

sealed class BankSlipEvent extends Equatable {
  const BankSlipEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a LISTA por [status] derivado ('open'|'settled'|'cancelled' —
/// null mantém a aba atual) e [filter] de nosso número/documento (null
/// mantém). Paginação D3: [page] navega (aba/filtro novos voltam à página
/// 1 — default); [pageSize] null mantém o tamanho corrente (1º load =
/// config page_size resolvida pela API — D4).
class BankSlipListRequested extends BankSlipEvent {
  const BankSlipListRequested({
    this.status,
    this.filter,
    this.page = 1,
    this.pageSize,
  });

  final String? status;
  final String? filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [status, filter, page, pageSize];
}

/// Tap na linha → carrega o DETALHE do boleto.
class BankSlipViewRequested extends BankSlipEvent {
  const BankSlipViewRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Voltar do detalhe → recarrega a lista onde o usuário estava.
class BankSlipBackToListPressed extends BankSlipEvent {
  const BankSlipBackToListPressed();
}

/// Confirmação do dialog Emitir: POST /api/bank-slips — sucesso abre o
/// detalhe do boleto novo; os 409 de negócio (título quitado/já com
/// boleto/clientes misturados...) chegam pela ponte como veio da API.
class BankSlipIssueRequested extends BankSlipEvent {
  const BankSlipIssueRequested(this.input);
  final BankSlipIssueInput input;

  @override
  List<Object?> get props => [input];
}

/// Liquidação manual (dialog Baixar do detalhe aberto) — evento L.
class BankSlipSettleRequested extends BankSlipEvent {
  const BankSlipSettleRequested({
    required this.slip,
    required this.paidValue,
    required this.dtPayment,
  });

  final BankSlipFull slip;
  final double paidValue;

  /// ISO 'yyyy-MM-dd'.
  final String dtPayment;

  @override
  List<Object?> get props => [slip, paidValue, dtPayment];
}

/// Cancelamento (dialog Cancelar do detalhe aberto) — evento C.
class BankSlipCancelRequested extends BankSlipEvent {
  const BankSlipCancelRequested({required this.slip, this.note});

  final BankSlipFull slip;
  final String? note;

  @override
  List<Object?> get props => [slip, note];
}

/// Estorno da liquidação (dialog Estornar do detalhe liquidado) — evento X.
class BankSlipReverseRequested extends BankSlipEvent {
  const BankSlipReverseRequested({required this.slip, required this.reason});

  final BankSlipFull slip;
  final String reason;

  @override
  List<Object?> get props => [slip, reason];
}
