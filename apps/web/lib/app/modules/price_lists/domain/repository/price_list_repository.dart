import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/price_list_entity.dart';

/// Contrato do repositório de Tabelas de Preço (Either/dartz).
abstract class PriceListRepository {
  Future<Either<Failure, PagedResult<PriceListEntity>>> getList(String filter,
      {int page, int? pageSize, SearchCriteriaValues criteria});
  Future<Either<Failure, PriceListEntity>> getById(int id);
  Future<Either<Failure, int>> post(PriceListInput input);
  Future<Either<Failure, Unit>> put(int id, PriceListInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
