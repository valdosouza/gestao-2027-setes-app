import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/city_entity.dart';

/// Contrato do repositório de Cidade (decisão 12: `Either<Failure, T>` via dartz).
abstract class CityRepository {
  Future<Either<Failure, List<CityEntity>>> getList(String filter);
  Future<Either<Failure, int>> post(CityEntity city);
  Future<Either<Failure, Unit>> put(CityEntity city);
  Future<Either<Failure, Unit>> delete(int id);
}
