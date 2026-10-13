import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_nfse_repository.dart';

/// A VOZ do fisco sobre a nota da OS (nfse-api — GET /v1/nfse/invoices/{id}):
/// estado, tentativa vigente, linha do tempo, XML/DANFSe disponíveis. F2b.
class ServiceOrderFiscalGet {
  const ServiceOrderFiscalGet({required this.repository});

  final ServiceOrderNfseRepository repository;

  Future<Either<Failure, ServiceOrderFiscalView>> call(int orderId) => repository.getView(orderId);
}
