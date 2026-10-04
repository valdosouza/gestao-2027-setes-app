import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/service_entity.dart';
import '../repository/service_repository.dart';

/// Lista os Serviços da institution (filtro REMOTO), uma PÁGINA por vez.
class ServiceGetlist {
  const ServiceGetlist({required this.repository});

  final ServiceRepository repository;

  Future<Either<Failure, PagedResult<ServiceListItem>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
