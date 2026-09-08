import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_contract_entity.dart';

/// Contrato do repositório de Contratos Financeiros (Either/dartz).
abstract class FinancialContractRepository {
  Future<Either<Failure, PagedResult<FinancialContractListItem>>> getList(
      String filter,
      {int page, int? pageSize});
  Future<Either<Failure, FinancialContractFull>> getById(int id);
  Future<Either<Failure, int>> post(FinancialContractInput input);
  Future<Either<Failure, Unit>> put(int id, FinancialContractInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
