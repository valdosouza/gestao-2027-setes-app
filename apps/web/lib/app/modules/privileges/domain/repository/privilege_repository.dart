import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/privilege_entity.dart';

/// Contrato do repositório de Privilégio (decisão 12: `Either<Failure, T>` via dartz).
abstract class PrivilegeRepository {
  Future<Either<Failure, PagedResult<PrivilegeEntity>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, int>> post(PrivilegeEntity privilege);
  Future<Either<Failure, Unit>> put(PrivilegeEntity privilege);
  Future<Either<Failure, Unit>> delete(int id);
}
