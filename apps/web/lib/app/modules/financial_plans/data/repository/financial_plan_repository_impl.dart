import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/financial_plan_entity.dart';
import '../../domain/repository/financial_plan_repository.dart';
import '../datasource/financial_plan_datasource.dart';

class FinancialPlanRepositoryImpl implements FinancialPlanRepository {
  const FinancialPlanRepositoryImpl({required this.datasource});

  final FinancialPlanDatasource datasource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      return Left(Failure(message: err.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FinancialPlanEntity>>> getList() =>
      _guard(() => datasource.getList());

  @override
  Future<Either<Failure, int>> post(FinancialPlanEntity plan) =>
      _guard(() => datasource.post(plan));

  @override
  Future<Either<Failure, Unit>> put(FinancialPlanEntity plan) =>
      _guard(() async {
        await datasource.put(plan);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
