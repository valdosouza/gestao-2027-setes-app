import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// Consultar a transmissão no fisco (POST /api/billing/fiscal/:orderId/refresh):
/// consulta por chave, grava a voz nova (idempotente) e marca "nós olhamos
/// o fisco" (D-I20). É a reconciliação do desfecho ambíguo (S sem resposta,
/// K em voo — D-I21).
class ServiceOrderFiscalRefresh {
  const ServiceOrderFiscalRefresh({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> call(int orderId) =>
      repository.refresh(orderId);
}
