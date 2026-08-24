import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/order_repository.dart';

/// Abre uma DEVOLUÇÃO ancorada no pedido de venda FATURADO (ação
/// "Devolver" do detalhe — POST /api/order-returns {saleOrderId}, HTTP
/// direto: módulo nunca importa módulo). A condução da devolução (itens,
/// cancelamento, faturamento) é do módulo order_returns — o sucesso aqui
/// só navega para lá. Devolve o id da devolução criada.
class OrderReturnOpen {
  const OrderReturnOpen({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, int>> call(int saleOrderId) =>
      repository.openReturn(saleOrderId);
}
