import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/check_entity.dart';
import '../../domain/repository/check_repository.dart';
import '../datasource/check_datasource.dart';

class CheckRepositoryImpl implements CheckRepository {
  const CheckRepositoryImpl({required this.datasource});

  final CheckDatasource datasource;

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
  Future<Either<Failure, PagedResult<CheckListRow>>> getList(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() =>
          datasource.getList(status, filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, CheckFull>> getOne(int id) =>
      _guard(() => datasource.getOne(id));

  @override
  Future<Either<Failure, CheckSettledResult>> deposit(
          int id, String dtRecord, int bankAccountId) =>
      _guard(() => datasource.deposit(id, dtRecord, bankAccountId));

  @override
  Future<Either<Failure, CheckSettledResult>> discount(int id,
          String dtRecord, int factoringEntityId, int bankAccountId, double feeValue) =>
      _guard(() => datasource.discount(
          id, dtRecord, factoringEntityId, bankAccountId, feeValue));

  @override
  Future<Either<Failure, CheckSettledResult>> returnRefund(
          int id, String dtRecord, int bankAccountId) =>
      _guard(() => datasource.returnRefund(id, dtRecord, bankAccountId));

  @override
  Future<Either<Failure, int>> returnGood(int id, String? note) =>
      _guard(() => datasource.returnGood(id, note));

  @override
  Future<Either<Failure, CheckSettledResult>> pay(
          int id, String dtRecord, int orderId, int parcel) =>
      _guard(() => datasource.pay(id, dtRecord, orderId, parcel));

  @override
  Future<Either<Failure, CheckReturnResult>> returnToOrigin(
          int id, String dtRecord, String? note) =>
      _guard(() => datasource.returnToOrigin(id, dtRecord, note));

  @override
  Future<Either<Failure, CheckReverseResult>> reverse(
          int id, int event, String reason) =>
      _guard(() => datasource.reverse(id, event, reason));
}
