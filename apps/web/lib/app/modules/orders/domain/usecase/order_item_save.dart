import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Inclui ([itemId] null) ou altera um item do pedido aberto — o backend
/// decide sozinho mercadoria×serviço pelo kind do produto; o totalizer é
/// recalculado no servidor.
class OrderItemSave {
  const OrderItemSave({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, Unit>> call(
      int orderId, int? itemId, OrderItemInput input) async {
    if (itemId != null) return repository.itemPut(orderId, itemId, input);
    return (await repository.itemPost(orderId, input)).map((_) => unit);
  }
}
