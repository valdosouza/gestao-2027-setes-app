import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/country_entity.dart';
import '../repository/country_repository.dart';

class CountryPost {
  const CountryPost({required this.repository});

  final CountryRepository repository;

  Future<Either<Failure, int>> call(CountryEntity country) =>
      repository.post(country);
}
