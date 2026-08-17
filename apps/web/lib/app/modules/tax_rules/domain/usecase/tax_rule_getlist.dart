import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/tax_rule_list_item.dart';
import '../repository/tax_rule_repository.dart';

/// Lista as Regras de Tributação (filtro por NCM/descrição do produto),
/// uma PÁGINA por vez (paginação D3).
class TaxRuleGetlist {
  const TaxRuleGetlist({required this.repository});

  final TaxRuleRepository repository;

  Future<Either<Failure, PagedResult<TaxRuleListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
