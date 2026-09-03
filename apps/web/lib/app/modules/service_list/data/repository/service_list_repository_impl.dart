import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_list_entity.dart';
import '../../domain/repository/service_list_repository.dart';
import '../datasource/service_list_datasource.dart';

class ServiceListRepositoryImpl implements ServiceListRepository {
  const ServiceListRepositoryImpl({required this.datasource});

  final ServiceListDatasource datasource;

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
  Future<Either<Failure, PagedResult<ServiceListEntity>>> getList(
          String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, Unit>> post(ServiceListEntity item) =>
      _guard(() async {
        await datasource.post(item);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> put(ServiceListEntity item) =>
      _guard(() async {
        await datasource.put(item);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(String id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
