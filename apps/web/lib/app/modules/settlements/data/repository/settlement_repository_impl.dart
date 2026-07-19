import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/settlement_entity.dart';
import '../../domain/repository/settlement_repository.dart';
import '../datasource/settlement_datasource.dart';

class SettlementRepositoryImpl implements SettlementRepository {
  const SettlementRepositoryImpl({required this.datasource});

  final SettlementDatasource datasource;

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
  Future<Either<Failure, List<SettlementBill>>> bills(
          String status, String kind, String filter) =>
      _guard(() => datasource.bills(status, kind, filter));

  @override
  Future<Either<Failure, SettlementBatchResult>> settle(
          SettlementBatchInput input) =>
      _guard(() => datasource.settle(input));

  @override
  Future<Either<Failure, List<SettlementSettled>>> settled(String filter) =>
      _guard(() => datasource.settled(filter));

  @override
  Future<Either<Failure, SettlementReversalResult>> reversal(
          int orderId, int parcel, int event, String reason) =>
      _guard(() => datasource.reversal(orderId, parcel, event, reason));

  @override
  Future<Either<Failure, SettlementStatementReport>> statements(
          int bankAccountId, String? dtFrom, String? dtTo) =>
      _guard(() => datasource.statements(bankAccountId, dtFrom, dtTo));
}
