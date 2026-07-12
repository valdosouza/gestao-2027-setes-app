import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/users/entity/user_entity.dart';
import '../../domain/repository/user_repository.dart';
import '../../../../shared/users/datasource/user_datasource.dart';

class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({required this.datasource});

  final UserDatasource datasource;

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
  Future<Either<Failure, List<UserListItem>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, UserEntity>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, int>> post(UserEntity user) =>
      _guard(() => datasource.post(user));

  @override
  Future<Either<Failure, Unit>> put(UserEntity user) => _guard(() async {
        await datasource.put(user);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
