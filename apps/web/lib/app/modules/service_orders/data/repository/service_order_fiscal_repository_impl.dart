import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';
import '../../domain/repository/service_order_fiscal_repository.dart';
import '../datasource/service_order_fiscal_datasource.dart';

class ServiceOrderFiscalRepositoryImpl implements ServiceOrderFiscalRepository {
  const ServiceOrderFiscalRepositoryImpl({required this.datasource});

  final ServiceOrderFiscalDatasource datasource;

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
  Future<Either<Failure, ServiceOrderFiscalView>> getView(int orderId) =>
      _guard(() => datasource.getView(orderId));

  @override
  Future<Either<Failure, ServiceOrderTransmitResult>> transmit(int orderId) =>
      _guard(() => datasource.transmit(orderId));

  @override
  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> refresh(
          int orderId) =>
      _guard(() => datasource.refresh(orderId));

  @override
  Future<Either<Failure, String>> xml(int orderId) =>
      _guard(() => datasource.xml(orderId));

  @override
  Future<Either<Failure, String>> danfse(int orderId) =>
      _guard(() => datasource.danfse(orderId));

  @override
  Future<Either<Failure, ServiceOrderFiscalCancelResult>> cancel(
          int orderId, String reason) =>
      _guard(() => datasource.cancel(orderId, reason));

  @override
  Future<Either<Failure, List<ServiceOrderFiscalPending>>> pending() =>
      _guard(datasource.pending);

  @override
  Future<Either<Failure, FiscalTransmitBatchReport>> transmitBatch(
          List<int> orderIds) =>
      _guard(() => datasource.transmitBatch(orderIds));
}
