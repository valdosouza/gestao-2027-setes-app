import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_return_entity.dart';

/// Contrato do repositório da Devolução de Mercadoria (Either/dartz) —
/// operações do PROCESSO: lista por status, detalhe, abrir/cancelar,
/// quantidade/remoção de item e faturamento (validate/invoice via
/// /api/billing com adjustment = { cfopId }).
abstract class OrderReturnRepository {
  Future<Either<Failure, PagedResult<OrderReturnListItem>>> getList(
      String status, String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, OrderReturnFull>> getById(int id);
  Future<Either<Failure, int>> open(int saleOrderId);
  Future<Either<Failure, Unit>> cancel(int id);
  Future<Either<Failure, Unit>> itemQuantityPut(
      int returnId, int itemId, double quantity);
  Future<Either<Failure, Unit>> itemDelete(int returnId, int itemId);
  Future<Either<Failure, OrderReturnBillingValidation>> billingValidate(
      int returnId, String cfopId);
  Future<Either<Failure, OrderReturnBillingInvoice>> billingInvoice(
      int returnId, String cfopId);
}
