import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_return_entity.dart';
import '../repository/order_return_repository.dart';

/// Devolução completa (GET /api/order-returns/:id) — itens com
/// maxQuantity + total calculado no servidor.
class OrderReturnGet {
  const OrderReturnGet({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, OrderReturnFull>> call(int id) =>
      repository.getById(id);
}
