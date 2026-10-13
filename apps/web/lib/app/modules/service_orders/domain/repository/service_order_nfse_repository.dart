import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';

/// A NFS-e da OS na nfse-api (Either/dartz) — F2b, D-F4/D-F139. Separado do
/// [ServiceOrderInvoiceRepository] (fatos do ERP): duas APIs, dois contratos.
abstract class ServiceOrderNfseRepository {
  Future<Either<Failure, ServiceOrderFiscalView>> getView(int invoiceId);
  Future<Either<Failure, ServiceOrderTransmitResult>> transmit(int invoiceId);
  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> refresh(int invoiceId);
  Future<Either<Failure, ServiceOrderFiscalReconfirmResult>> reconfirm(int invoiceId);
  Future<Either<Failure, ServiceOrderFiscalCancelResult>> cancel(int invoiceId, String reason);
  Future<Either<Failure, String>> xml(int invoiceId);
  Future<Either<Failure, String>> danfse(int invoiceId);
  Future<Either<Failure, PagedResult<ServiceOrderFiscalPending>>> pending({int page = 1, int pageSize = 100});
}
