import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';

/// Contrato do repositório de Boletos (Either/dartz) — operações do
/// PROCESSO: lista por estado, detalhe, emitir, liquidar, cancelar e
/// estornar.
abstract class BankSlipRepository {
  Future<Either<Failure, PagedResult<BankSlipListRow>>> getList(
      String status, String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, BankSlipFull>> getOne(int id);
  Future<Either<Failure, BankSlipIssueResult>> issue(BankSlipIssueInput input);
  Future<Either<Failure, BankSlipSettleResult>> settle(
      int id, double paidValue, String dtPayment);
  Future<Either<Failure, int>> cancel(int id, String? note);
  Future<Either<Failure, BankSlipReverseResult>> reverse(int id, String reason);
}
