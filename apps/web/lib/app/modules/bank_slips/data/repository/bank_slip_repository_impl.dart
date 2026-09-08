import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/bank_slip_entity.dart';
import '../../domain/repository/bank_slip_repository.dart';
import '../datasource/bank_slip_datasource.dart';

class BankSlipRepositoryImpl implements BankSlipRepository {
  const BankSlipRepositoryImpl({required this.datasource});

  final BankSlipDatasource datasource;

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
  Future<Either<Failure, PagedResult<BankSlipListRow>>> getList(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() =>
          datasource.getList(status, filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, BankSlipFull>> getOne(int id) =>
      _guard(() => datasource.getOne(id));

  @override
  Future<Either<Failure, BankSlipIssueResult>> issue(
          BankSlipIssueInput input) =>
      _guard(() => datasource.issue(input));

  @override
  Future<Either<Failure, BankSlipSettleResult>> settle(
          int id, double paidValue, String dtPayment) =>
      _guard(() => datasource.settle(id, paidValue, dtPayment));

  @override
  Future<Either<Failure, int>> cancel(int id, String? note) =>
      _guard(() => datasource.cancel(id, note));

  @override
  Future<Either<Failure, BankSlipReverseResult>> reverse(
          int id, String reason) =>
      _guard(() => datasource.reverse(id, reason));
}
