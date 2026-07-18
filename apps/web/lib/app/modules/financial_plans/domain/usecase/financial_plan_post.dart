import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_plan_entity.dart';
import '../repository/financial_plan_repository.dart';

class FinancialPlanPost {
  const FinancialPlanPost({required this.repository});

  final FinancialPlanRepository repository;

  Future<Either<Failure, int>> call(FinancialPlanEntity plan) =>
      repository.post(plan);
}
