import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/order_entity.dart';
import '../../domain/repository/order_repository.dart';
import '../datasource/order_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl({required this.datasource});

  final OrderDatasource datasource;

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
  Future<Either<Failure, PagedResult<OrderListItem>>> getList(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() =>
          datasource.getList(status, filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, OrderFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> open(int customerId, int? salesmanId) =>
      _guard(() => datasource.open(customerId, salesmanId));

  @override
  Future<Either<Failure, Unit>> cancel(int id) => _guard(() async {
        await datasource.cancel(id);
        return unit;
      });

  @override
  Future<Either<Failure, int>> itemPost(int orderId, OrderItemInput input) =>
      _guard(() => datasource.itemPost(orderId, input));

  @override
  Future<Either<Failure, Unit>> itemPut(
          int orderId, int itemId, OrderItemInput input) =>
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
  Future<Either<Failure, OrderBillingValidation>> billingValidate(
          int orderId) =>
      _guard(() => datasource.billingValidate(orderId));

  @override
  Future<Either<Failure, OrderBillingInvoice>> billingInvoice(int orderId) =>
      _guard(() => datasource.billingInvoice(orderId));

  @override
  Future<Either<Failure, int>> openReturn(int saleOrderId) =>
      _guard(() => datasource.openReturn(saleOrderId));
}
