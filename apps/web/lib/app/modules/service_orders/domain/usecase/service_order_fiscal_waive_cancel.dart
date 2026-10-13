import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_invoice_repository.dart';

/// "Manter a nota" (ERP — POST /api/billing/cancel-waiver, D-F67): a NFS-e foi
/// SUBSTITUÍDA no fisco (e105102) e o humano decide NÃO cancelar a nota. Cabe
/// quando o efeito é `decide` (D-F142 — o servidor diz). 409
/// INVOICE_CANCEL_WAIVER_NOT_APPLICABLE = a situação mudou (a tela relê);
/// repetir é idempotente (`alreadyWaived`).
class ServiceOrderFiscalWaiveCancel {
  const ServiceOrderFiscalWaiveCancel({required this.repository});

  final ServiceOrderInvoiceRepository repository;

  Future<Either<Failure, ServiceOrderCancelWaiverResult>> call(int orderId, String reason) =>
      repository.cancelWaiver(orderId, reason);
}
