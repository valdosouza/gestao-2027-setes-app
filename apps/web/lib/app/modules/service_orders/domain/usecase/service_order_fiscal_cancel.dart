import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// Cancelar a NFS-e autorizada (POST /api/billing/fiscal/cancel — Onda 3
/// §3 Composições): plano local → estado fiscal → pedido ao fisco → voz →
/// efeito. Baixa/boleto/cheque bloqueiam ANTES do fisco (409
/// INVOICE_CANCEL_BLOCKED com blocos em fields[]); fisco recusa = 409
/// FISCAL_CANCEL_REFUSED e nada muda; ambíguo = kind 'K' em voo. Sucesso 'C'
/// = C local na mesma transação (a OS volta a aberta).
class ServiceOrderFiscalCancel {
  const ServiceOrderFiscalCancel({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, ServiceOrderFiscalCancelResult>> call(
          int orderId, String reason) =>
      repository.cancel(orderId, reason);
}
