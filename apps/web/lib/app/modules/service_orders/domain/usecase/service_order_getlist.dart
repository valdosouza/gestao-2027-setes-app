import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// Página das OS da institution por [status] 'A'|'F' e filtro de cliente
/// (paginação D3: [pageSize] null = config page_size da API — D4).
class ServiceOrderGetlist {
  const ServiceOrderGetlist({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, PagedResult<ServiceOrderListItem>>> call(
          String status, String filter,
          {int page = 1, int? pageSize, SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(status, filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
