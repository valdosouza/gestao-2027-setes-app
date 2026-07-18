import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_plan_entity.dart';
import '../repository/financial_plan_repository.dart';

class FinancialPlanGetlist {
  const FinancialPlanGetlist({required this.repository});

  final FinancialPlanRepository repository;

  Future<Either<Failure, List<FinancialPlanEntity>>> call() =>
      repository.getList();
}
