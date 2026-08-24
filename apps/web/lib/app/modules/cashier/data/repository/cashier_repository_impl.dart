import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/cashier_entity.dart';
import '../../domain/repository/cashier_repository.dart';
import '../datasource/cashier_datasource.dart';

class CashierRepositoryImpl implements CashierRepository {
  const CashierRepositoryImpl({required this.datasource});

  final CashierDatasource datasource;

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
  Future<Either<Failure, CashierRow?>> current() =>
      _guard(() => datasource.current());

  @override
  Future<Either<Failure, CashierRow>> open() => _guard(() => datasource.open());

  @override
  Future<Either<Failure, CashierDetail>> detail(int id) =>
      _guard(() => datasource.detail(id));

  @override
  Future<Either<Failure, CashierWithdrawResult>> withdraw(
          int id, CashierWithdrawInput input) =>
      _guard(() => datasource.withdraw(id, input));

  @override
  Future<Either<Failure, CashierCloseResult>> close(
          int id, CashierCloseInput input) =>
      _guard(() => datasource.close(id, input));
}
