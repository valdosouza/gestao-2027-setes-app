import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_salesman.dart';
import '../../domain/repository/salesman_repository.dart';
import '../datasource/salesman_datasource.dart';

class SalesmanRepositoryImpl implements SalesmanRepository {
  const SalesmanRepositoryImpl({required this.datasource});

  final SalesmanDatasource datasource;

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
  Future<Either<Failure, PagedResult<SalesmanListItem>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, ObjectSalesman>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, int>> post(ObjectSalesman salesman) =>
      _guard(() => datasource.post(salesman));

  @override
  Future<Either<Failure, Unit>> put(ObjectSalesman salesman) =>
      _guard(() async {
        await datasource.put(salesman);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
