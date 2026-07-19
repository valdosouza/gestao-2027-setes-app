part of 'settlement_bloc.dart';

sealed class SettlementEvent extends Equatable {
  const SettlementEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a aba EM ABERTO (bills?status=open) com o [filter] de
/// entidade/nº do título — a consulta é SEMPRE da API (saldo derivado).
class SettlementBillsRequested extends SettlementEvent {
  const SettlementBillsRequested({this.filter});

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  @override
  List<Object?> get props => [filter];
}

/// Confirmação do dialog de baixa: POST do LOTE — sucesso mostra o nº do
/// código gerado na SnackBar e recarrega a carteira.
class SettlementSettleRequested extends SettlementEvent {
  const SettlementSettleRequested(this.input);
  final SettlementBatchInput input;

  @override
  List<Object?> get props => [input];
}

/// Carrega a aba BAIXADOS (linha por evento) com o [filter].
class SettlementSettledRequested extends SettlementEvent {
  const SettlementSettledRequested({this.filter});

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  @override
  List<Object?> get props => [filter];
}

/// Estorna a baixa VIGENTE (motivo já coletado no dialog) — o 409 da API
/// ("baixa não vigente") vira SnackBar com a mensagem como veio.
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
