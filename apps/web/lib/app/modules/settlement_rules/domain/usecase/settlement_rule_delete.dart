import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/settlement_rule_repository.dart';

class SettlementRuleDelete {
  const SettlementRuleDelete({required this.repository});

  final SettlementRuleRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
