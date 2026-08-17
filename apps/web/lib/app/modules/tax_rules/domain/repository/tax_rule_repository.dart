import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/tax_rule_catalogs.dart';
import '../entity/tax_rule_draft.dart';
import '../entity/tax_rule_list_item.dart';

/// Contrato do repositório de Regras de Tributação (decisão 12:
/// `Either<Failure, T>` via dartz).
abstract class TaxRuleRepository {
  Future<Either<Failure, PagedResult<TaxRuleListItem>>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, TaxRuleDraft>> getById(int id);
  Future<Either<Failure, TaxRuleCatalogs>> getCatalogs();
  Future<Either<Failure, Unit>> post(TaxRuleDraft draft);
  Future<Either<Failure, Unit>> put(TaxRuleDraft draft);
  Future<Either<Failure, Unit>> delete(int id);
}
