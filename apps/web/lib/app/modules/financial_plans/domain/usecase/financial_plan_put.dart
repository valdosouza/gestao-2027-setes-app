import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_plan_entity.dart';
import '../repository/financial_plan_repository.dart';

class FinancialPlanPut {
  const FinancialPlanPut({required this.repository});

  final FinancialPlanRepository repository;

  Future<Either<Failure, Unit>> call(FinancialPlanEntity plan) =>
      repository.put(plan);
}
