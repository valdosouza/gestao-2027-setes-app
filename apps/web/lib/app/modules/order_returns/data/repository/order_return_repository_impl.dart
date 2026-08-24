import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/order_return_entity.dart';
import '../../domain/repository/order_return_repository.dart';
import '../datasource/order_return_datasource.dart';

class OrderReturnRepositoryImpl implements OrderReturnRepository {
  const OrderReturnRepositoryImpl({required this.datasource});

  final OrderReturnDatasource datasource;

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
  Future<Either<Failure, PagedResult<OrderReturnListItem>>> getList(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() =>
          datasource.getList(status, filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, OrderReturnFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> open(int saleOrderId) =>
      _guard(() => datasource.open(saleOrderId));

  @override
  Future<Either<Failure, Unit>> cancel(int id) => _guard(() async {
        await datasource.cancel(id);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> itemQuantityPut(
          int returnId, int itemId, double quantity) =>
      _guard(() async {
        await datasource.itemQuantityPut(returnId, itemId, quantity);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> itemDelete(int returnId, int itemId) =>
      _guard(() async {
        await datasource.itemDelete(returnId, itemId);
        return unit;
      });

  @override
  Future<Either<Failure, OrderReturnBillingValidation>> billingValidate(
          int returnId, String cfopId) =>
      _guard(() => datasource.billingValidate(returnId, cfopId));

  @override
  Future<Either<Failure, OrderReturnBillingInvoice>> billingInvoice(
          int returnId, String cfopId) =>
      _guard(() => datasource.billingInvoice(returnId, cfopId));
}
