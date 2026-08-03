import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_salesman.dart';

/// Contrato do repositório de Vendedor (Either/dartz).
abstract class SalesmanRepository {
  Future<Either<Failure, PagedResult<SalesmanListItem>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, ObjectSalesman>> get(int id);
  Future<Either<Failure, int>> post(ObjectSalesman salesman);
  Future<Either<Failure, Unit>> put(ObjectSalesman salesman);
  Future<Either<Failure, Unit>> delete(int id);
}
