import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Grava a negociação (PUT /api/orders/:id/negotiation): `installments`
/// presente = via ELABORADA (substitui a grade); ausente = "voltar ao
/// prazo" (a API apaga o elaborado). Devolve a negociação recomposta.
class OrderNegotiationSave {
  const OrderNegotiationSave({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, OrderNegotiation>> call(
          int orderId, OrderNegotiationInput input) =>
      repository.putNegotiation(orderId, input);
}
