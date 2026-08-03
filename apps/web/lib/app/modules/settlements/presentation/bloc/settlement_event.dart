part of 'settlement_bloc.dart';

sealed class SettlementEvent extends Equatable {
  const SettlementEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a aba EM ABERTO (bills?status=open) com o [filter] de
/// entidade/nº do título — a consulta é SEMPRE da API (saldo derivado).
/// Paginação D3: [page] navega (filtro novo volta à página 1 — default);
/// [pageSize] null mantém o tamanho corrente (1º load = config page_size
/// resolvida pela API — D4). Navegar/filtrar NÃO mexe na seleção múltipla
/// (ela vive no bloc — só a baixa/estorno limpam).
class SettlementBillsRequested extends SettlementEvent {
  const SettlementBillsRequested({this.filter, this.page = 1, this.pageSize});

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Marca/desmarca UM título na seleção múltipla da aba Em aberto. O bloc
/// guarda o TÍTULO inteiro (não só a chave): a soma dos selecionados e o
/// dialog de baixa continuam corretos mesmo com seleção fora da página
/// visível.
class SettlementBillToggled extends SettlementEvent {
  const SettlementBillToggled(this.bill);
  final SettlementBill bill;

  @override
  List<Object?> get props => [bill];
}

/// Confirmação do dialog de baixa: POST do LOTE — sucesso mostra o nº do
/// código gerado na SnackBar e recarrega a carteira.
class SettlementSettleRequested extends SettlementEvent {
  const SettlementSettleRequested(this.input);
  final SettlementBatchInput input;

  @override
  List<Object?> get props => [input];
}

/// Carrega a aba BAIXADOS (linha por evento) com o [filter]. Paginação
/// D3: [page] navega (filtro novo volta à página 1 — default); [pageSize]
/// null mantém o tamanho corrente.
class SettlementSettledRequested extends SettlementEvent {
  const SettlementSettledRequested({this.filter, this.page = 1, this.pageSize});

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Estorna a baixa VIGENTE (motivo já coletado no dialog) — o 409 da API
/// ("baixa não vigente") vira dialog de validação com a mensagem como
/// veio, via ponte de feedback.
class SettlementReversalRequested extends SettlementEvent {
  const SettlementReversalRequested({
    required this.orderId,
    required this.parcel,
    required this.event,
    required this.reason,
  });

  final int    orderId;
  final int    parcel;
  final int    event;
  final String reason;

  @override
  List<Object?> get props => [orderId, parcel, event, reason];
}

/// Carrega a aba MOVIMENTO — conta (0 = Caixa, default) e período
/// opcionais; totais e saldo vêm prontos da API.
class SettlementStatementsRequested extends SettlementEvent {
  const SettlementStatementsRequested({
    this.bankAccountId,
    this.dtFrom,
    this.dtTo,
  });

  /// null = mantém a conta atual do bloc (default 0 = Caixa).
  final int? bankAccountId;

  /// ISO 'yyyy-MM-dd'; null = mantém o valor atual do bloc.
  final String? dtFrom;
  final String? dtTo;

  @override
  List<Object?> get props => [bankAccountId, dtFrom, dtTo];
}
