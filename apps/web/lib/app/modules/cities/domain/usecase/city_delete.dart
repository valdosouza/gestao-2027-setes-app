import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/city_repository.dart';

class CityDelete {
  const CityDelete({required this.repository});

  final CityRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
