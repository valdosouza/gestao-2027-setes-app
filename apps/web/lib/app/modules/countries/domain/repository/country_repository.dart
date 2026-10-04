import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/country_entity.dart';

/// Contrato do repositório de País (decisão 12: `Either<Failure, T>` via dartz).
abstract class CountryRepository {
  Future<Either<Failure, PagedResult<CountryEntity>>> getList(String filter,
      {int page, int? pageSize, SearchCriteriaValues criteria});
  Future<Either<Failure, int>> post(CountryEntity country);
  Future<Either<Failure, Unit>> put(CountryEntity country);
  Future<Either<Failure, Unit>> delete(int id);
}
