import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_tax_rule_entity.dart';

/// Contrato do repositório de Regras de Tributação de Serviço (Either/dartz).
abstract class ServiceTaxRuleRepository {
  Future<Either<Failure, PagedResult<ServiceTaxRuleEntity>>> getList(
      String filter,
      {int page, int? pageSize});
  Future<Either<Failure, ServiceTaxRuleEntity>> getById(int id);
  Future<Either<Failure, int>> post(ServiceTaxRuleInput input);
  Future<Either<Failure, Unit>> put(int id, ServiceTaxRuleInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
