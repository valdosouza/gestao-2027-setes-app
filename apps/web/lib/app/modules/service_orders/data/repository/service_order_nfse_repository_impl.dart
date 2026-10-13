import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';
import '../../domain/repository/service_order_nfse_repository.dart';
import '../datasource/service_order_nfse_datasource.dart';

class ServiceOrderNfseRepositoryImpl implements ServiceOrderNfseRepository {
  const ServiceOrderNfseRepositoryImpl({required this.datasource});

  final ServiceOrderNfseDatasource datasource;

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
  Future<Either<Failure, ServiceOrderFiscalView>> getView(int invoiceId) =>
      _guard(() => datasource.getView(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderTransmitResult>> transmit(int invoiceId) =>
      _guard(() => datasource.transmit(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> refresh(int invoiceId) =>
      _guard(() => datasource.refresh(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderFiscalReconfirmResult>> reconfirm(int invoiceId) =>
      _guard(() => datasource.reconfirm(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderFiscalCancelResult>> cancel(int invoiceId, String reason) =>
      _guard(() => datasource.cancel(invoiceId, reason));

  @override
  Future<Either<Failure, String>> xml(int invoiceId) => _guard(() => datasource.xml(invoiceId));

  @override
  Future<Either<Failure, String>> danfse(int invoiceId) => _guard(() => datasource.danfse(invoiceId));

  @override
  Future<Either<Failure, PagedResult<ServiceOrderFiscalPending>>> pending({int page = 1, int pageSize = 100}) =>
      _guard(() => datasource.pending(page: page, pageSize: pageSize));
}
