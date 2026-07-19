import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/repository/service_order_repository.dart';
import '../datasource/service_order_datasource.dart';

class ServiceOrderRepositoryImpl implements ServiceOrderRepository {
  const ServiceOrderRepositoryImpl({required this.datasource});

  final ServiceOrderDatasource datasource;

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
  Future<Either<Failure, List<ServiceOrderListItem>>> getList(
          String status, String filter) =>
      _guard(() => datasource.getList(status, filter));

  @override
  Future<Either<Failure, ServiceOrderFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> open(int customerId) =>
      _guard(() => datasource.open(customerId));

  @override
  Future<Either<Failure, Unit>> cancel(int id) => _guard(() async {
        await datasource.cancel(id);
        return unit;
      });

  @override
  Future<Either<Failure, int>> itemPost(
          int orderId, ServiceOrderItemInput input) =>
      _guard(() => datasource.itemPost(orderId, input));

  @override
  Future<Either<Failure, Unit>> itemPut(
          int orderId, int itemId, ServiceOrderItemInput input) =>
      _guard(() async {
        await datasource.itemPut(orderId, itemId, input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> itemDelete(int orderId, int itemId) =>
      _guard(() async {
        await datasource.itemDelete(orderId, itemId);
        return unit;
      });

  @override
  Future<Either<Failure, MonthlyRunReport>> monthlyRun(int year, int month) =>
      _guard(() => datasource.monthlyRun(year, month));

  @override
  Future<Either<Failure, ServiceOrderInvoiceResult>> invoice(
          int orderId, ServiceOrderInvoiceInput input) =>
      _guard(() => datasource.invoice(orderId, input));
}
