import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_carrier.dart';

/// Contrato do repositório de Transportadora (Either/dartz).
abstract class CarrierRepository {
  Future<Either<Failure, PagedResult<CarrierListItem>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, ObjectCarrier>> get(int id);
  Future<Either<Failure, CarrierPostResult>> post(ObjectCarrier carrier);
  Future<Either<Failure, Unit>> put(ObjectCarrier carrier);
  Future<Either<Failure, Unit>> delete(int id);
}
