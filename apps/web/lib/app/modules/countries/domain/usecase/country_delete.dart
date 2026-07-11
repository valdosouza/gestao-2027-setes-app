import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/country_repository.dart';

class CountryDelete {
  const CountryDelete({required this.repository});

  final CountryRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
