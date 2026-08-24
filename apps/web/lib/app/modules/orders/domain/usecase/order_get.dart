import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Carrega o pedido completo (itens + totalizer) para o detalhe.
class OrderGet {
  const OrderGet({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, OrderFull>> call(int id) => repository.getById(id);
}
