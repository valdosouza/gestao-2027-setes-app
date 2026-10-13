import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_nfse_repository.dart';

/// "Consultar" (nfse-api — POST /v1/nfse/invoices/{id}/refresh): consulta ativa
/// ao fisco; grava a voz nova (idempotente).
class ServiceOrderFiscalRefresh {
  const ServiceOrderFiscalRefresh({required this.repository});

  final ServiceOrderNfseRepository repository;

  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> call(int orderId) => repository.refresh(orderId);
}
