import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_return_repository.dart';

/// Altera a QUANTIDADE do item da devolução aberta (único campo editável —
/// teto = maxQuantity; 422 RETURN_INVALID acima do saldo, 409
/// ORDER_INVOICED se já faturada). O total é recalculado no servidor.
class OrderReturnItemQuantityPut {
  const OrderReturnItemQuantityPut({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, Unit>> call(int returnId, int itemId, double quantity) =>
      repository.itemQuantityPut(returnId, itemId, quantity);
}
