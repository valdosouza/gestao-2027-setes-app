import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/entity/service_order_fiscal_entity.dart';
import '../../domain/repository/service_order_invoice_repository.dart';
import '../datasource/service_order_invoice_datasource.dart';

class ServiceOrderInvoiceRepositoryImpl implements ServiceOrderInvoiceRepository {
  const ServiceOrderInvoiceRepositoryImpl({required this.datasource});

  final ServiceOrderInvoiceDatasource datasource;

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
  Future<Either<Failure, ServiceOrderCancelPlan>> cancelPlan(int orderId) =>
      _guard(() => datasource.cancelPlan(orderId));

  @override
  Future<Either<Failure, ServiceOrderFiscalEffect>> fiscalEffect(int orderId) =>
      _guard(() => datasource.fiscalEffect(orderId));

  @override
  Future<Either<Failure, ServiceOrderInvoiceCancelResult>> cancel(int orderId, String reason) =>
      _guard(() => datasource.cancel(orderId, reason));

  @override
  Future<Either<Failure, ServiceOrderCancelWaiverResult>> cancelWaiver(int orderId, String reason) =>
      _guard(() => datasource.cancelWaiver(orderId, reason));
}
