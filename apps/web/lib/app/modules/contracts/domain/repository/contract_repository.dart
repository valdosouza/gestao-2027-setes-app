import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/contract_entity.dart';

/// Contrato do repositório de Contratos de serviço (Either/dartz).
abstract class ContractRepository {
  Future<Either<Failure, PagedResult<ContractListItem>>> getList(String filter,
      {int page, int? pageSize, SearchCriteriaValues criteria});
  Future<Either<Failure, ContractFull>> getById(int id);
  Future<Either<Failure, int>> post(ContractInput input);
  Future<Either<Failure, Unit>> put(int id, ContractInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
