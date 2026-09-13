import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_rule_entity.dart';
import '../repository/settlement_rule_repository.dart';

class SettlementRulePost {
  const SettlementRulePost({required this.repository});

  final SettlementRuleRepository repository;

  Future<Either<Failure, int>> call(SettlementRuleInput input) =>
      repository.post(input);
}
