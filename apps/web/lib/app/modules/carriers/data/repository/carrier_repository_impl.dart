import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_carrier.dart';
import '../../domain/repository/carrier_repository.dart';
import '../datasource/carrier_datasource.dart';

class CarrierRepositoryImpl implements CarrierRepository {
  const CarrierRepositoryImpl({required this.datasource});

  final CarrierDatasource datasource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      return Left(Failure(message: err.toString()));
    }
  }

  @override
  Future<Either<Failure, PagedResult<CarrierListItem>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, ObjectCarrier>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, CarrierPostResult>> post(ObjectCarrier carrier) =>
      _guard(() => datasource.post(carrier));

  @override
  Future<Either<Failure, Unit>> put(ObjectCarrier carrier) => _guard(() async {
        await datasource.put(carrier);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
