import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// Notas faturadas SEM NFS-e (GET /api/billing/fiscal/pending) — alimenta a
/// confirmação do lote "Transmitir pendentes" da aba Faturadas.
class ServiceOrderFiscalPendingList {
  const ServiceOrderFiscalPendingList({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, List<ServiceOrderFiscalPending>>> call() =>
      repository.pending();
}
