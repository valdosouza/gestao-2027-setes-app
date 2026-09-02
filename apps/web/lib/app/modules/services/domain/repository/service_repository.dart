import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_entity.dart';

/// Contrato do repositório de Serviços (Either/dartz).
abstract class ServiceRepository {
  Future<Either<Failure, PagedResult<ServiceListItem>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, ServiceFull>> getById(int id);

  /// Grade vazia do serviço NOVO (tabelas de preço vivas).
  Future<Either<Failure, List<ServicePrice>>> priceLists();
  Future<Either<Failure, int>> post(ServiceInput input);
  Future<Either<Failure, Unit>> put(int id, ServiceInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
