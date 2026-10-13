import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_invoice_repository.dart';

/// O EFEITO da voz do fisco na nota (ERP — GET /api/billing/:orderId/
/// fiscal-effect, D-F114): none/apply/decide/cancel + a dispensa vigente. A
/// falha é a SEGUNDA falha da seção (D-F139): "efeito indisponível", nunca
/// "nada pendente".
class ServiceOrderFiscalEffectGet {
  const ServiceOrderFiscalEffectGet({required this.repository});

  final ServiceOrderInvoiceRepository repository;

  Future<Either<Failure, ServiceOrderFiscalEffect>> call(int orderId) => repository.fiscalEffect(orderId);
}
