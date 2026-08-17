import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/tax_rule_draft.dart';
import '../repository/tax_rule_repository.dart';

/// Atualiza a regra (seletor + ressincroniza as peças — toggle desligado
/// vira peça ausente e a API a remove).
class TaxRulePut {
  const TaxRulePut({required this.repository});

  final TaxRuleRepository repository;

  Future<Either<Failure, Unit>> call(TaxRuleDraft draft) =>
      repository.put(draft);
}
