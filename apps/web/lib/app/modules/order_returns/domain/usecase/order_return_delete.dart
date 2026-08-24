import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_return_repository.dart';

/// Cancela a devolução ABERTA (DELETE /api/order-returns/:id — 409
/// ORDER_INVOICED se já faturada).
class OrderReturnDelete {
  const OrderReturnDelete({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.cancel(id);
}
