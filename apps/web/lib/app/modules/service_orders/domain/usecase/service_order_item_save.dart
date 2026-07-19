import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// Inclui ([itemId] null) ou altera um item da OS aberta — o totalizer é
/// recalculado no servidor.
class ServiceOrderItemSave {
  const ServiceOrderItemSave({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, Unit>> call(
      int orderId, int? itemId, ServiceOrderItemInput input) async {
    if (itemId != null) return repository.itemPut(orderId, itemId, input);
    return (await repository.itemPost(orderId, input)).map((_) => unit);
  }
}
