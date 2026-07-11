import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/country_entity.dart';
import '../repository/country_repository.dart';

class CountryPut {
  const CountryPut({required this.repository});

  final CountryRepository repository;

  Future<Either<Failure, Unit>> call(CountryEntity country) =>
      repository.put(country);
}
