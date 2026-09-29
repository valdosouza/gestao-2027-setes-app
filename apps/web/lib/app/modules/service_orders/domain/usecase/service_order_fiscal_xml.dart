import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_fiscal_repository.dart';

/// XML autorizado da NFS-e (GET /api/billing/fiscal/:orderId/xml) — texto;
/// a tela abre em nova aba.
class ServiceOrderFiscalXml {
  const ServiceOrderFiscalXml({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, String>> call(int orderId) => repository.xml(orderId);
}
