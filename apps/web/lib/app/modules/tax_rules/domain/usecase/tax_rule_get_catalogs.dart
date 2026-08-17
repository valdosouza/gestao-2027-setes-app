import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/tax_rule_catalogs.dart';
import '../repository/tax_rule_repository.dart';

/// Catálogos fiscais centrais (CSTs, modalidades de base, desoneração) para
/// os combos do form — carregados UMA vez na abertura (o bloc cacheia).
class TaxRuleGetCatalogs {
  const TaxRuleGetCatalogs({required this.repository});

  final TaxRuleRepository repository;

  Future<Either<Failure, TaxRuleCatalogs>> call() =>
      repository.getCatalogs();
}
