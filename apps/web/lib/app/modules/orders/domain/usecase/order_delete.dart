import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_repository.dart';

/// Cancela o pedido ABERTO (soft delete; 409 se já faturado).
class OrderDelete {
  const OrderDelete({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.cancel(id);
}
