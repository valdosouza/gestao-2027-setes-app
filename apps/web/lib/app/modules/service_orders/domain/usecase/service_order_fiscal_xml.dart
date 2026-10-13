import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_nfse_repository.dart';

/// XML da NFS-e (nfse-api — GET /v1/nfse/invoices/{id}/xml).
class ServiceOrderFiscalXml {
  const ServiceOrderFiscalXml({required this.repository});

  final ServiceOrderNfseRepository repository;

  Future<Either<Failure, String>> call(int orderId) => repository.xml(orderId);
}
