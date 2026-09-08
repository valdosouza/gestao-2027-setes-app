import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_contract_entity.dart';
import '../repository/financial_contract_repository.dart';

/// Carrega o contrato COMPLETO (GET /:id) para edição — a lista não traz
/// a observação.
class FinancialContractGet {
  const FinancialContractGet({required this.repository});

  final FinancialContractRepository repository;

  Future<Either<Failure, FinancialContractFull>> call(int id) =>
      repository.getById(id);
}
