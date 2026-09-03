import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_tax_rule_entity.dart';
import '../repository/service_tax_rule_repository.dart';

class ServiceTaxRulePut {
  const ServiceTaxRulePut({required this.repository});

  final ServiceTaxRuleRepository repository;

  Future<Either<Failure, Unit>> call(int id, ServiceTaxRuleInput input) =>
      repository.put(id, input);
}
