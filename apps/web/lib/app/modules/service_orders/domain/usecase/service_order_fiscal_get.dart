import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// Visão fiscal da nota da OS faturada (GET /api/billing/fiscal/:orderId —
/// Onda 3): transmissões do DPS + voz do fisco + XML/DANFSe disponíveis.
class ServiceOrderFiscalGet {
  const ServiceOrderFiscalGet({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, ServiceOrderFiscalView>> call(int orderId) =>
      repository.getView(orderId);
}
