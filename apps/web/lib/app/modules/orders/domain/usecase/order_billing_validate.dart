import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Valida o pedido para faturamento (POST /api/billing/validate) — issues
/// vazio = pronto pra faturar.
class OrderBillingValidate {
  const OrderBillingValidate({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, OrderBillingValidation>> call(int orderId) =>
      repository.billingValidate(orderId);
}
