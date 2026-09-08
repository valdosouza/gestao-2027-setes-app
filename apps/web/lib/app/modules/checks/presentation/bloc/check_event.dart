part of 'check_bloc.dart';

sealed class CheckEvent extends Equatable {
  const CheckEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a LISTA por [status] derivado (um dos 6 de [CheckState]; null
/// mantém a aba atual) e [filter] de nº do cheque/emitente (null mantém).
/// [page] navega (aba/filtro novos voltam à página 1 — default); [pageSize]
/// null mantém o tamanho corrente (1º load = config page_size da API).
class CheckListRequested extends CheckEvent {
  const CheckListRequested({this.status, this.filter, this.page = 1, this.pageSize});

  final String? status;
  final String? filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [status, filter, page, pageSize];
}

/// Tap na linha → carrega o DETALHE do cheque.
class CheckViewRequested extends CheckEvent {
  const CheckViewRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Voltar do detalhe → recarrega a lista onde o usuário estava.
class CheckBackToListPressed extends CheckEvent {
  const CheckBackToListPressed();
}

/// Depositar (evento B) — dialog do detalhe em custódia.
class CheckDepositRequested extends CheckEvent {
  const CheckDepositRequested(
      {required this.check, required this.dtRecord, required this.bankAccountId});

  final CheckFull check;
  final String dtRecord;
  final int bankAccountId;

  @override
  List<Object?> get props => [check, dtRecord, bankAccountId];
}

/// Descontar na factoring (evento D) — dialog do detalhe em custódia.
class CheckDiscountRequested extends CheckEvent {
  const CheckDiscountRequested({
    required this.check,
    required this.dtRecord,
    required this.factoringEntityId,
    required this.bankAccountId,
    required this.feeValue,
  });

  final CheckFull check;
  final String dtRecord;
  final int factoringEntityId;
  final int bankAccountId;
  final double feeValue;

  @override
  List<Object?> get props =>
      [check, dtRecord, factoringEntityId, bankAccountId, feeValue];
}

/// Retorno com reembolso (evento T) — dialog do detalhe na factoring.
class CheckReturnRefundRequested extends CheckEvent {
  const CheckReturnRefundRequested(
      {required this.check, required this.dtRecord, required this.bankAccountId});

  final CheckFull check;
  final String dtRecord;
  final int bankAccountId;

  @override
  List<Object?> get props => [check, dtRecord, bankAccountId];
}

/// Retorno bom (evento F) — dialog do detalhe na factoring, sem movimento.
class CheckReturnGoodRequested extends CheckEvent {
  const CheckReturnGoodRequested({required this.check, this.note});

  final CheckFull check;
  final String? note;

  @override
  List<Object?> get props => [check, note];
}

/// Usar em pagamento (evento P) — dialog do detalhe em custódia.
class CheckPayRequested extends CheckEvent {
  const CheckPayRequested({
    required this.check,
    required this.dtRecord,
    required this.orderId,
    required this.parcel,
  });

  final CheckFull check;
  final String dtRecord;
  final int orderId;
  final int parcel;

  @override
  List<Object?> get props => [check, dtRecord, orderId, parcel];
}

/// Devolver (evento V) — dialog do detalhe em custódia; cria título novo.
class CheckReturnRequested extends CheckEvent {
  const CheckReturnRequested({required this.check, required this.dtRecord, this.note});

  final CheckFull check;
  final String dtRecord;
  final String? note;

  @override
  List<Object?> get props => [check, dtRecord, note];
}

/// Estornar o último evento (evento X) — disponível em qualquer estado;
/// [event] é sempre o nº do evento mais recente ([CheckFull.lastEvent]).
class CheckReverseRequested extends CheckEvent {
  const CheckReverseRequested(
      {required this.check, required this.event, required this.reason});

  final CheckFull check;
  final int event;
  final String reason;

  @override
  List<Object?> get props => [check, event, reason];
}
