import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_nfse_repository.dart';

/// "Transmitir" (nfse-api — POST /v1/nfse/invoices/{id}/transmit): 201 só com
/// a NFS-e AUTORIZADA. 422 FISCAL_DPS_REJECTED traz os E0xxx em fields[];
/// 409 com a mensagem; 502/503/rede = desfecho DESCONHECIDO (a tentativa pode
/// estar em voo — a tela relê e oferece "Consultar"; nunca reenvia sozinha).
class ServiceOrderTransmit {
  const ServiceOrderTransmit({required this.repository});

  final ServiceOrderNfseRepository repository;

  Future<Either<Failure, ServiceOrderTransmitResult>> call(int orderId) => repository.transmit(orderId);
}
