import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// Lote de transmissão (POST /api/billing/fiscal/transmit-batch, ≤ 50 por
/// requisição): a API responde 200 mesmo com recusas parciais — o relatório
/// é o resultado. Quem fatia e agrega é o bloc.
class ServiceOrderFiscalTransmitBatch {
  const ServiceOrderFiscalTransmitBatch({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, FiscalTransmitBatchReport>> call(
          List<int> orderIds) =>
      repository.transmitBatch(orderIds);
}
