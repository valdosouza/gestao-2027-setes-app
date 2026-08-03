import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/country_entity.dart';
import '../repository/country_repository.dart';

/// Lista os Países (filtro por nome), uma PÁGINA por vez (paginação D3).
class CountryGetlist {
  const CountryGetlist({required this.repository});

  final CountryRepository repository;

  Future<Either<Failure, PagedResult<CountryEntity>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
