import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/city_entity.dart';
import '../repository/city_repository.dart';

class CityPost {
  const CityPost({required this.repository});

  final CityRepository repository;

  Future<Either<Failure, int>> call(CityEntity city) => repository.post(city);
}
