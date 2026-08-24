import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_return_repository.dart';

/// Remove o item da devolução aberta — sem re-inclusão (removeu errado →
/// cancela a devolução e reabre pelo pedido de origem).
class OrderReturnItemDelete {
  const OrderReturnItemDelete({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, Unit>> call(int returnId, int itemId) =>
      repository.itemDelete(returnId, itemId);
}
