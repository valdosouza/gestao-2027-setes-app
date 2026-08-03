import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/state_entity.dart';
import '../../domain/repository/state_repository.dart';
import '../datasource/state_datasource.dart';

class StateRepositoryImpl implements StateRepository {
  const StateRepositoryImpl({required this.datasource});

  final StateDatasource datasource;

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
  Future<Either<Failure, PagedResult<StateEntity>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, int>> post(StateEntity state) =>
      _guard(() => datasource.post(state));

  @override
  Future<Either<Failure, Unit>> put(StateEntity state) => _guard(() async {
        await datasource.put(state);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
