import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/tax_rule_draft.dart';
import '../repository/tax_rule_repository.dart';

/// Cria a regra (seletor + peças na MESMA transação da API; id = MAX+1 no
/// backend).
class TaxRulePost {
  const TaxRulePost({required this.repository});

  final TaxRuleRepository repository;

  Future<Either<Failure, Unit>> call(TaxRuleDraft draft) =>
      repository.post(draft);
}
