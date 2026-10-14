import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../../domain/entity/service_order_entity.dart';
import '../../domain/repository/service_order_repository.dart';
import '../datasource/service_order_datasource.dart';

class ServiceOrderRepositoryImpl implements ServiceOrderRepository {
  const ServiceOrderRepositoryImpl({required this.datasource});

  final ServiceOrderDatasource datasource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      // LD-ADV-04 = LD-SOC-02 (Q-1 (a), gates do último delta): erro de LEITURA da resposta (tipo trocado num item) é falha técnica com
      // código (`CLIENT_INVALID_RESPONSE`) — nunca o texto do Dart como mensagem do diálogo (a regra da F2B-ADV-12/D-F210; os
      // repositórios irmãos nfse/invoice já seguiam). Os outros 36 repositórios do app = tarefa própria
      return Left(invalidResponseFailure(err));
    }
  }

  @override
  Future<Either<Failure, PagedResult<ServiceOrderListItem>>> getList(
          String status, String filter,
          {int page = 1, int? pageSize, SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      _guard(() => datasource.getList(status, filter,
          page: page, pageSize: pageSize, criteria: criteria));

  @override
  Future<Either<Failure, ServiceOrderFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> open(int customerId) =>
      _guard(() => datasource.open(customerId));

  @override
  Future<Either<Failure, Unit>> cancel(int id) => _guard(() async {
        await datasource.cancel(id);
        return unit;
      });

  @override
  Future<Either<Failure, int>> itemPost(
          int orderId, ServiceOrderItemInput input) =>
      _guard(() => datasource.itemPost(orderId, input));

  @override
  Future<Either<Failure, Unit>> itemPut(
          int orderId, int itemId, ServiceOrderItemInput input) =>
      _guard(() async {
        await datasource.itemPut(orderId, itemId, input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> itemDelete(int orderId, int itemId) =>
      _guard(() async {
        await datasource.itemDelete(orderId, itemId);
        return unit;
      });

  @override
  Future<Either<Failure, MonthlyRunReport>> monthlyRun(int year, int month) =>
      _guard(() => datasource.monthlyRun(year, month));

  @override
  Future<Either<Failure, ServiceOrderInvoiceResult>> invoice(
          int orderId, ServiceOrderInvoiceInput input) =>
      _guard(() => datasource.invoice(orderId, input));

  @override
  Future<Either<Failure, BatchInvoiceReport>> batchInvoice(
          List<int> orderIds, ServiceOrderInvoiceInput input) =>
      _guard(() => datasource.batchInvoice(orderIds, input));
}
