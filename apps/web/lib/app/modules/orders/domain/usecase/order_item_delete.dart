import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_repository.dart';

/// Remove um item do pedido aberto (soft delete; totalizer recalculado).
class OrderItemDelete {
  const OrderItemDelete({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, Unit>> call(int orderId, int itemId) =>
      repository.itemDelete(orderId, itemId);
}
