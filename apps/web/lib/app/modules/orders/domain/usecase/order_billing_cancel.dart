import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Cancela a NOTA de um pedido faturado (prompt_cancelamento_nota.md,
/// Onda 1 — nota não transmitida): POST /api/billing/cancel {orderId,
/// reason}. Motivo obrigatório (D13). A API recusa com 409
/// INVOICE_CANCEL_BLOCKED + fields[] tipado quando há título baixado,
/// boleto liquidado, cheque que avançou ou devolução vigente (D2/D8/D9/
/// D10) — a tela lista o que resolver antes. Sucesso: pedido volta a
/// aberto (D5) e some da aba Faturados.
class OrderBillingCancelUsecase {
  const OrderBillingCancelUsecase({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, OrderBillingCancel>> call(int orderId, String reason) =>
      repository.billingCancel(orderId, reason);
}
