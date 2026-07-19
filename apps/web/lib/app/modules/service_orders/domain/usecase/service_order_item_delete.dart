import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_repository.dart';

/// Remove um item da OS aberta (soft delete; totalizer recalculado).
class ServiceOrderItemDelete {
  const ServiceOrderItemDelete({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, Unit>> call(int orderId, int itemId) =>
      repository.itemDelete(orderId, itemId);
}
