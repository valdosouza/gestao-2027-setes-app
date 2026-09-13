import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_rule_entity.dart';
import '../repository/settlement_rule_repository.dart';

/// Carrega o contrato COMPLETO (GET /:id) para edição — a lista não traz
/// a observação.
class SettlementRuleGet {
  const SettlementRuleGet({required this.repository});

  final SettlementRuleRepository repository;

  Future<Either<Failure, SettlementRuleFull>> call(int id) =>
      repository.getById(id);
}
