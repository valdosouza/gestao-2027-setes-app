import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_return_entity.dart';
import '../repository/order_return_repository.dart';

/// Valida a devolução para faturamento (POST /api/billing/validate com
/// adjustment = { cfopId }) — issues vazio = pronto pra faturar.
class OrderReturnBillingValidate {
  const OrderReturnBillingValidate({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, OrderReturnBillingValidation>> call(
          int returnId, String cfopId) =>
      repository.billingValidate(returnId, cfopId);
}
