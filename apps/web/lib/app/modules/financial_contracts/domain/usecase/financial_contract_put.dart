import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_contract_entity.dart';
import '../repository/financial_contract_repository.dart';

class FinancialContractPut {
  const FinancialContractPut({required this.repository});

  final FinancialContractRepository repository;

  Future<Either<Failure, Unit>> call(int id, FinancialContractInput input) =>
      repository.put(id, input);
}
