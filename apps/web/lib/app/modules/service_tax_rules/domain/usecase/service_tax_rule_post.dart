import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_tax_rule_entity.dart';
import '../repository/service_tax_rule_repository.dart';

class ServiceTaxRulePost {
  const ServiceTaxRulePost({required this.repository});

  final ServiceTaxRuleRepository repository;

  Future<Either<Failure, int>> call(ServiceTaxRuleInput input) =>
      repository.post(input);
}
