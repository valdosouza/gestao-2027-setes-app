import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/service_tax_rule_entity.dart';
import '../repository/service_tax_rule_repository.dart';

/// Lista as regras de tributação de serviço da institution (filtro REMOTO
/// por cidade/item/descrição), uma PÁGINA por vez.
class ServiceTaxRuleGetlist {
  const ServiceTaxRuleGetlist({required this.repository});

  final ServiceTaxRuleRepository repository;

  Future<Either<Failure, PagedResult<ServiceTaxRuleEntity>>> call(
          String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
