import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/tax_rule_draft.dart';
import '../repository/tax_rule_repository.dart';

/// Busca a regra COMPLETA (seletor + peças presentes) antes de abrir a
/// edição — a lista carrega só o resumo com flags has*.
class TaxRuleGet {
  const TaxRuleGet({required this.repository});

  final TaxRuleRepository repository;

  Future<Either<Failure, TaxRuleDraft>> call(int id) =>
      repository.getById(id);
}
