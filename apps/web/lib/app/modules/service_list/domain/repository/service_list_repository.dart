import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_list_entity.dart';

/// Contrato do repositório da Lista de Serviços (Either/dartz).
abstract class ServiceListRepository {
  Future<Either<Failure, PagedResult<ServiceListEntity>>> getList(
      String filter,
      {int page, int? pageSize});
  Future<Either<Failure, Unit>> post(ServiceListEntity item);
  Future<Either<Failure, Unit>> put(ServiceListEntity item);
  Future<Either<Failure, Unit>> delete(String id);
}
