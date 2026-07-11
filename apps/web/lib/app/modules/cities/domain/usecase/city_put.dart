import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/city_entity.dart';
import '../repository/city_repository.dart';

class CityPut {
  const CityPut({required this.repository});

  final CityRepository repository;

  Future<Either<Failure, Unit>> call(CityEntity city) => repository.put(city);
}
