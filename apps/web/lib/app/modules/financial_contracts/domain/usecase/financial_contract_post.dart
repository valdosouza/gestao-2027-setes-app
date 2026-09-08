import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_contract_entity.dart';
import '../repository/financial_contract_repository.dart';

class FinancialContractPost {
  const FinancialContractPost({required this.repository});

  final FinancialContractRepository repository;

  Future<Either<Failure, int>> call(FinancialContractInput input) =>
      repository.post(input);
}
