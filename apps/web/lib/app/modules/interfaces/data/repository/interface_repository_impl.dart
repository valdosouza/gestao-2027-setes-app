import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/interface_entity.dart';
import '../../domain/repository/interface_repository.dart';
import '../datasource/interface_datasource.dart';

class InterfaceRepositoryImpl implements InterfaceRepository {
  const InterfaceRepositoryImpl({required this.datasource});

  final InterfaceDatasource datasource;

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
  Future<Either<Failure, List<InterfaceEntity>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, int>> post(InterfaceEntity entity) =>
      _guard(() => datasource.post(entity));

  @override
  Future<Either<Failure, Unit>> put(InterfaceEntity entity) =>
      _guard(() async {
        await datasource.put(entity);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
