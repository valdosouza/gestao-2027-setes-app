import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_invoice_repository.dart';

/// O PLANO de cancelamento (ERP — GET /api/billing/:orderId/cancel-plan,
/// D-F128/D-F131/D-F141): o mesmo cálculo do POST, sem gravar. A tela decide
/// o próximo passo SÓ por ele (cancelável · NFS-e autorizada · reconferir ·
/// bloqueios). 403 sem o privilégio CANCELAR.
class ServiceOrderCancelPlanGet {
  const ServiceOrderCancelPlanGet({required this.repository});

  final ServiceOrderInvoiceRepository repository;

  Future<Either<Failure, ServiceOrderCancelPlan>> call(int orderId) => repository.cancelPlan(orderId);
}
