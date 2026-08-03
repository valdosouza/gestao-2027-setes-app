import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/interface_entity.dart';

/// Contrato do repositório de Interface (decisão 12: `Either<Failure, T>` via dartz).
abstract class InterfaceRepository {
  Future<Either<Failure, PagedResult<InterfaceEntity>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, int>> post(InterfaceEntity entity);
  Future<Either<Failure, Unit>> put(InterfaceEntity entity);
  Future<Either<Failure, Unit>> delete(int id);
}
