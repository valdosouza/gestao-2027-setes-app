import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/service_list_entity.dart';

/// Contrato do repositório da Lista de Serviços (Either/dartz).
abstract class ServiceListRepository {
  Future<Either<Failure, PagedResult<ServiceListEntity>>> getList(
      String filter,
      {int page, int? pageSize, SearchCriteriaValues criteria});
  Future<Either<Failure, Unit>> post(ServiceListEntity item);
  Future<Either<Failure, Unit>> put(ServiceListEntity item);
  Future<Either<Failure, Unit>> delete(String id);
}
