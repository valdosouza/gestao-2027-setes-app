import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';

/// Contrato do repositório FISCAL da OS (Either/dartz) — Onda 3: visão
/// fiscal, transmitir, consultar, XML/DANFSe, cancelar NFS-e e o lote de
/// pendentes. Separado do [ServiceOrderRepository] porque fala com outro
/// endpoint (/api/billing/fiscal*), não com /api/service-orders.
abstract class ServiceOrderFiscalRepository {
  Future<Either<Failure, ServiceOrderFiscalView>> getView(int orderId);
  Future<Either<Failure, ServiceOrderTransmitResult>> transmit(int orderId);
  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> refresh(int orderId);
  Future<Either<Failure, String>> xml(int orderId);
  Future<Either<Failure, String>> danfse(int orderId);
  Future<Either<Failure, ServiceOrderFiscalCancelResult>> cancel(
      int orderId, String reason);
  Future<Either<Failure, List<ServiceOrderFiscalPending>>> pending();
  Future<Either<Failure, FiscalTransmitBatchReport>> transmitBatch(
      List<int> orderIds);
}
