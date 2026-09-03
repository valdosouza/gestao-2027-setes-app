import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_tax_rule_entity.dart';
import '../repository/service_tax_rule_repository.dart';

/// Carrega a regra (GET /:id) para edição.
class ServiceTaxRuleGet {
  const ServiceTaxRuleGet({required this.repository});

  final ServiceTaxRuleRepository repository;

  Future<Either<Failure, ServiceTaxRuleEntity>> call(int id) =>
      repository.getById(id);
}
