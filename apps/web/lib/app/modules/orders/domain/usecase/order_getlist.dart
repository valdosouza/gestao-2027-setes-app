import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_entity.dart';
import '../repository/order_repository.dart';

/// Página dos pedidos da institution por [status] 'A'|'F' e filtro de
/// cliente (paginação: [pageSize] null = config page_size da API).
class OrderGetlist {
  const OrderGetlist({required this.repository});

  final OrderRepository repository;

  Future<Either<Failure, PagedResult<OrderListItem>>> call(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(status, filter, page: page, pageSize: pageSize);
}
