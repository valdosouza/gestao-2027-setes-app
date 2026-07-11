import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/privilege_entity.dart';
import '../../domain/repository/privilege_repository.dart';
import '../datasource/privilege_datasource.dart';

class PrivilegeRepositoryImpl implements PrivilegeRepository {
  const PrivilegeRepositoryImpl({required this.datasource});

  final PrivilegeDatasource datasource;

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
  Future<Either<Failure, List<PrivilegeEntity>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, int>> post(PrivilegeEntity privilege) =>
      _guard(() => datasource.post(privilege));

  @override
  Future<Either<Failure, Unit>> put(PrivilegeEntity privilege) =>
      _guard(() async {
        await datasource.put(privilege);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
