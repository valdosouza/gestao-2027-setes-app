import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/bank_entity.dart';
import '../../domain/repository/bank_repository.dart';
import '../datasource/bank_datasource.dart';

class BankRepositoryImpl implements BankRepository {
  const BankRepositoryImpl({required this.datasource});

  final BankDatasource datasource;

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
  Future<Either<Failure, PagedResult<BankEntity>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, int>> post(BankEntity bank) =>
      _guard(() => datasource.post(bank));

  @override
  Future<Either<Failure, Unit>> put(BankEntity bank) =>
      _guard(() async {
        await datasource.put(bank);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
