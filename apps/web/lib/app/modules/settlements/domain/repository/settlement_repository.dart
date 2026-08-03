import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';

/// Contrato do repositório da Baixa de Títulos (Either/dartz) — operações
/// do PROCESSO: carteira, baixa em lote, baixados, estorno e movimento.
abstract class SettlementRepository {
  Future<Either<Failure, PagedResult<SettlementBill>>> bills(
      String status, String kind, String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, SettlementBatchResult>> settle(
      SettlementBatchInput input);
  Future<Either<Failure, PagedResult<SettlementSettled>>> settled(
      String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, SettlementReversalResult>> reversal(
      int orderId, int parcel, int event, String reason);
  Future<Either<Failure, SettlementStatementReport>> statements(
      int bankAccountId, String? dtFrom, String? dtTo);
}
