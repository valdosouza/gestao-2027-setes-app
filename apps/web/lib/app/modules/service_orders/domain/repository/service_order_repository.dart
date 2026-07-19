import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';

/// Contrato do repositório de Ordens de Serviço (Either/dartz) — operações
/// do PROCESSO: lista por status, detalhe, abrir/cancelar OS, itens,
/// rotina mensal e Gerar Faturamento.
abstract class ServiceOrderRepository {
  Future<Either<Failure, List<ServiceOrderListItem>>> getList(
      String status, String filter);
  Future<Either<Failure, ServiceOrderFull>> getById(int id);
  Future<Either<Failure, int>> open(int customerId);
  Future<Either<Failure, Unit>> cancel(int id);
  Future<Either<Failure, int>> itemPost(
      int orderId, ServiceOrderItemInput input);
  Future<Either<Failure, Unit>> itemPut(
      int orderId, int itemId, ServiceOrderItemInput input);
  Future<Either<Failure, Unit>> itemDelete(int orderId, int itemId);
  Future<Either<Failure, MonthlyRunReport>> monthlyRun(int year, int month);
  Future<Either<Failure, ServiceOrderInvoiceResult>> invoice(
      int orderId, ServiceOrderInvoiceInput input);
}
