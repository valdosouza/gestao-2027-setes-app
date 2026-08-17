import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/tax_rule_repository.dart';

/// Exclui a regra (soft delete do seletor + peças, decisão 4).
class TaxRuleDelete {
  const TaxRuleDelete({required this.repository});

  final TaxRuleRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
