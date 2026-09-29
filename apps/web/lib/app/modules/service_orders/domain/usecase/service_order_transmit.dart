import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_fiscal_repository.dart';

/// Transmitir o DPS da nota da OS ao ADN (POST /api/billing/transmit —
/// Onda 3 §3 B). A API reserva `attempt` sob lock da nota, fala com o fisco
/// FORA da transação e grava a voz (S/A); DPS rejeitado = 422
/// FISCAL_DPS_REJECTED com os códigos E0xxx em fields[]; transmissão
/// vigente = 409; fisco fora = 503 — tudo [Failure] legível pela ponte.
class ServiceOrderTransmit {
  const ServiceOrderTransmit({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, ServiceOrderTransmitResult>> call(int orderId) =>
      repository.transmit(orderId);
}
