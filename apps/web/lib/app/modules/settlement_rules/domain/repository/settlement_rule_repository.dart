import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_rule_entity.dart';

/// Contrato do repositório de Regras de Recebimento (Either/dartz).
abstract class SettlementRuleRepository {
  Future<Either<Failure, PagedResult<SettlementRuleListItem>>> getList(
      String filter,
      {int page, int? pageSize});
  Future<Either<Failure, SettlementRuleFull>> getById(int id);
  Future<Either<Failure, int>> post(SettlementRuleInput input);
  Future<Either<Failure, Unit>> put(int id, SettlementRuleInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
