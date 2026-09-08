import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Fatura o pedido (POST /api/billing/invoice) — só chamar depois de um
/// validate sem issues. [checks] = cheques por parcela (D5 da negociação):
/// obrigatório para toda parcela cuja forma é cheque; vazio quando nenhuma
/// parcela é cheque (fluxo inalterado).
class OrderBillingInvoiceUsecase {
  const OrderBillingInvoiceUsecase({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, OrderBillingInvoice>> call(int orderId,
          {List<OrderParcelChecksInput> checks = const []}) =>
      repository.billingInvoice(orderId, checks: checks);
}
