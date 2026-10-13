import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_nfse_repository.dart';

/// "Reconferir" (nfse-api — POST /v1/nfse/invoices/{id}/reconfirm, D-F109): o
/// envio foi interrompido e o plano pede a PROVA de que a NFS-e não existe.
/// O veredito só escolhe a frase; depois a tela RELÊ o plano (quem decide).
class ServiceOrderFiscalReconfirm {
  const ServiceOrderFiscalReconfirm({required this.repository});

  final ServiceOrderNfseRepository repository;

  Future<Either<Failure, ServiceOrderFiscalReconfirmResult>> call(int orderId) => repository.reconfirm(orderId);
}
