import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Lê a negociação do pedido (GET /api/orders/:id/negotiation): cabeçalho
/// da via simples, grade elaborada, preview gerado do prazo e base do
/// pedido — `mode` derivado pela API.
class OrderNegotiationGet {
  const OrderNegotiationGet({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, OrderNegotiation>> call(int orderId) =>
      repository.getNegotiation(orderId);
}
