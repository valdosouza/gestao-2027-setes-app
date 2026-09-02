import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_entity.dart';
import '../../domain/repository/service_repository.dart';
import '../datasource/service_datasource.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  const ServiceRepositoryImpl({required this.datasource});

  final ServiceDatasource datasource;

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
  Future<Either<Failure, PagedResult<ServiceListItem>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, ServiceFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, List<ServicePrice>>> priceLists() =>
      _guard(datasource.priceLists);

  @override
  Future<Either<Failure, int>> post(ServiceInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, ServiceInput input) =>
      _guard(() async {
        await datasource.put(id, input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
