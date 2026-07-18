import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_plan_entity.dart';

/// Contrato do repositório do Plano de Contas (Either/dartz).
abstract class FinancialPlanRepository {
  Future<Either<Failure, List<FinancialPlanEntity>>> getList();
  Future<Either<Failure, int>> post(FinancialPlanEntity plan);
  Future<Either<Failure, Unit>> put(FinancialPlanEntity plan);
  Future<Either<Failure, Unit>> delete(int id);
}
