import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/financial_plan_repository.dart';

class FinancialPlanDelete {
  const FinancialPlanDelete({required this.repository});

  final FinancialPlanRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
