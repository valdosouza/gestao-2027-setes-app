import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_fiscal_repository.dart';

/// DANFSe (GET /api/billing/fiscal/:orderId/danfse) — renderização NOSSA do
/// XML (Q-N13: a API do fisco está suspensa), base64 no envelope; a tela
/// abre em nova aba como o PDF do boleto.
class ServiceOrderFiscalDanfse {
  const ServiceOrderFiscalDanfse({required this.repository});

  final ServiceOrderFiscalRepository repository;

  Future<Either<Failure, String>> call(int orderId) =>
      repository.danfse(orderId);
}
