import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/financial_contract_repository.dart';

class FinancialContractDelete {
  const FinancialContractDelete({required this.repository});

  final FinancialContractRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
