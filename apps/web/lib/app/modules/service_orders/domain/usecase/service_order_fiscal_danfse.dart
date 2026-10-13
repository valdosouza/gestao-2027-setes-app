import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_nfse_repository.dart';

/// DANFSe em base64 (nfse-api — GET /v1/nfse/invoices/{id}/danfse).
class ServiceOrderFiscalDanfse {
  const ServiceOrderFiscalDanfse({required this.repository});

  final ServiceOrderNfseRepository repository;

  Future<Either<Failure, String>> call(int orderId) => repository.danfse(orderId);
}
