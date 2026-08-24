import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_return_entity.dart';
import '../repository/order_return_repository.dart';

/// Fatura a devolução (POST /api/billing/invoice com adjustment =
/// { cfopId }) — só chamar depois de um validate sem issues.
class OrderReturnBillingInvoiceUsecase {
  const OrderReturnBillingInvoiceUsecase({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, OrderReturnBillingInvoice>> call(
          int returnId, String cfopId) =>
      repository.billingInvoice(returnId, cfopId);
}
