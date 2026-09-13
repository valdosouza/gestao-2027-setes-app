import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_rule_entity.dart';
import '../repository/settlement_rule_repository.dart';

class SettlementRulePut {
  const SettlementRulePut({required this.repository});

  final SettlementRuleRepository repository;

  Future<Either<Failure, Unit>> call(int id, SettlementRuleInput input) =>
      repository.put(id, input);
}
