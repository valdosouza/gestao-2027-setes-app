import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../entity/service_order_fiscal_entity.dart';

/// Os FATOS DO ERP sobre a nota da OS (setes-api `/api/billing/*` — Either/
/// dartz): plano de cancelamento, efeito da voz do fisco, cancelar a nota e
/// "manter a nota". F2b, D-F115/D-F139.
abstract class ServiceOrderInvoiceRepository {
  Future<Either<Failure, ServiceOrderCancelPlan>> cancelPlan(int orderId);
  Future<Either<Failure, ServiceOrderFiscalEffect>> fiscalEffect(int orderId);
  Future<Either<Failure, ServiceOrderInvoiceCancelResult>> cancel(int orderId, String reason);
  Future<Either<Failure, ServiceOrderCancelWaiverResult>> cancelWaiver(int orderId, String reason);
}
