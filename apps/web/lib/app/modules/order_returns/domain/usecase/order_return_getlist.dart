import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/order_return_entity.dart';
import '../repository/order_return_repository.dart';

/// Página das devoluções da institution por [status] 'A'|'F' e filtro de
/// cliente (paginação: [pageSize] null = config page_size da API).
class OrderReturnGetlist {
  const OrderReturnGetlist({required this.repository});

  final OrderReturnRepository repository;

  Future<Either<Failure, PagedResult<OrderReturnListItem>>> call(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(status, filter, page: page, pageSize: pageSize);
}
