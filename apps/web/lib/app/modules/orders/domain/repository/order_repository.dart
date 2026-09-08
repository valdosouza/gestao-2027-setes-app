import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';

/// Contrato do repositório do Pedido de Venda/Conjugado (Either/dartz) —
/// operações do PROCESSO: lista por status, detalhe, abrir/cancelar,
/// itens, negociação (forma/prazo/parcelas) e faturamento (validate/
/// invoice com cheques por parcela, via /api/billing).
abstract class OrderRepository {
  Future<Either<Failure, PagedResult<OrderListItem>>> getList(
      String status, String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, OrderFull>> getById(int id);
  Future<Either<Failure, int>> open(int customerId, int? salesmanId);
  Future<Either<Failure, Unit>> cancel(int id);
  Future<Either<Failure, int>> itemPost(int orderId, OrderItemInput input);
  Future<Either<Failure, Unit>> itemPut(
      int orderId, int itemId, OrderItemInput input);
  Future<Either<Failure, Unit>> itemDelete(int orderId, int itemId);
  Future<Either<Failure, OrderBillingValidation>> billingValidate(int orderId);
  Future<Either<Failure, OrderBillingInvoice>> billingInvoice(int orderId,
      {List<OrderParcelChecksInput> checks = const []});
  Future<Either<Failure, OrderNegotiation>> getNegotiation(int orderId);
  Future<Either<Failure, OrderNegotiation>> putNegotiation(
      int orderId, OrderNegotiationInput input);
  Future<Either<Failure, int>> openReturn(int saleOrderId);
}
