import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_return_repository.dart';

/// Abre a devolução ancorada num pedido de venda FATURADO (POST
/// /api/order-returns {saleOrderId}) — itens pré-carregados pela API com o
/// saldo devolvível; 422 ORIGIN_NOT_INVOICED / NOTHING_RETURNABLE com
/// mensagem pronta. Devolve o id da devolução criada.
class OrderReturnPost {
  const OrderReturnPost({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, int>> call(int saleOrderId) =>
      repository.open(saleOrderId);
}
