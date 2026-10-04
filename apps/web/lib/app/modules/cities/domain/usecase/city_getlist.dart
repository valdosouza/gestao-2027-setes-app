import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/city_entity.dart';
import '../repository/city_repository.dart';

/// Lista as Cidades (filtro por nome), uma PÁGINA por vez (paginação D3).
class CityGetlist {
  const CityGetlist({required this.repository});

  final CityRepository repository;

  Future<Either<Failure, PagedResult<CityEntity>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
