import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// Gerar Faturamento: fatura interna 'SE' + financeiro RA + ordem A→F.
/// O vencimento vem DECIDIDO PELO USUÁRIO (DP1).
class ServiceOrderInvoice {
  const ServiceOrderInvoice({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, ServiceOrderInvoiceResult>> call(
          int orderId, ServiceOrderInvoiceInput input) =>
      repository.invoice(orderId, input);
}
