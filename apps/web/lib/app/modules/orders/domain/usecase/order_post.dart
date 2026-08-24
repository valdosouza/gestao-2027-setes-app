import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_repository.dart';

/// Abre o pedido para o cliente ([salesmanId] opcional — 400
/// SALESMAN_REQUIRED da API se nenhum default existir na carteira).
class OrderPost {
  const OrderPost({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, int>> call(int customerId, int? salesmanId) =>
      repository.open(customerId, salesmanId);
}
