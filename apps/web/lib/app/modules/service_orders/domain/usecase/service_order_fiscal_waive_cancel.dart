import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// "Manter a nota" (POST /api/billing/cancel-waiver — D-F67, Valdo
/// 2026-10-10): a NFS-e da nota foi cancelada POR SUBSTITUIÇÃO no fisco
/// (e105102, feito fora do produto) e o efeito local ficou suspenso (D-F64).
/// Esta é a decisão humana de MANTER a nota no ERP — nada é cancelado; a
/// pendência deixa de contar. Motivo obrigatório (1–255). 409
/// INVOICE_CANCEL_WAIVER_NOT_APPLICABLE = a decisão não cabe mais (não é
/// substituição, nota já cancelada ou efeito já aplicado); 403 = sem o
/// privilégio CANCELAR. Repetir é idempotente (`alreadyWaived`).
class ServiceOrderFiscalWaiveCancel {
  const ServiceOrderFiscalWaiveCancel({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, ServiceOrderCancelWaiverResult>> call(
          int orderId, String reason) =>
      repository.cancelWaiver(orderId, reason);
}
