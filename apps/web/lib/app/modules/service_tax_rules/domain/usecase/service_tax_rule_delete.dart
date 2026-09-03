import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_tax_rule_repository.dart';

/// Soft delete — a API responde 409 SERVICE_TAX_RULE_IN_USE quando um
/// serviço aponta a regra (a ponte de feedback exibe a mensagem).
class ServiceTaxRuleDelete {
  const ServiceTaxRuleDelete({required this.repository});

  final ServiceTaxRuleRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
