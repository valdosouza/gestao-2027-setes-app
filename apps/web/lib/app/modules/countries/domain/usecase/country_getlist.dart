import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/country_entity.dart';
import '../repository/country_repository.dart';

class CountryGetlist {
  const CountryGetlist({required this.repository});

  final CountryRepository repository;

  Future<Either<Failure, List<CountryEntity>>> call(String filter) =>
      repository.getList(filter);
}
