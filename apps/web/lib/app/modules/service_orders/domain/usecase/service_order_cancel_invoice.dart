import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// "Cancelar nota" da OS faturada (prompt_cancelamento_nota.md Q-G3/Q-G16):
/// POST /api/billing/cancel {orderId, reason}. Motivo obrigatório (D13). A
/// API recusa com 409 INVOICE_CANCEL_BLOCKED + fields[] tipado (título
/// baixado, boleto liquidado, outra OS aberta do cliente — trava D5); a tela
/// lista o que resolver antes. Sucesso: a OS volta a ABERTA e editável.
class ServiceOrderCancelInvoice {
  const ServiceOrderCancelInvoice({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, ServiceOrderInvoiceCancelResult>> call(
          int orderId, String reason) =>
      repository.cancelInvoice(orderId, reason);
}
