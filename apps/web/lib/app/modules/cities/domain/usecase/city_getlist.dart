import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/city_entity.dart';
import '../repository/city_repository.dart';

class CityGetlist {
  const CityGetlist({required this.repository});

  final CityRepository repository;

  Future<Either<Failure, List<CityEntity>>> call(String filter) =>
      repository.getList(filter);
}
