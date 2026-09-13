import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_rule_entity.dart';
import '../repository/settlement_rule_repository.dart';

/// Lista os Regras de Recebimento da institution (filtro REMOTO), uma
/// PÁGINA por vez (lista nova nasce paginada).
class SettlementRuleGetlist {
  const SettlementRuleGetlist({required this.repository});

  final SettlementRuleRepository repository;

  Future<Either<Failure, PagedResult<SettlementRuleListItem>>> call(
          String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
