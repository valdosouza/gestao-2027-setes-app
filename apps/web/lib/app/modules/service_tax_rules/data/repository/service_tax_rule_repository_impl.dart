import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_tax_rule_entity.dart';
import '../../domain/repository/service_tax_rule_repository.dart';
import '../datasource/service_tax_rule_datasource.dart';

class ServiceTaxRuleRepositoryImpl implements ServiceTaxRuleRepository {
  const ServiceTaxRuleRepositoryImpl({required this.datasource});

  final ServiceTaxRuleDatasource datasource;

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
  Future<Either<Failure, PagedResult<ServiceTaxRuleEntity>>> getList(
          String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, ServiceTaxRuleEntity>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(ServiceTaxRuleInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, ServiceTaxRuleInput input) =>
      _guard(() async {
        await datasource.put(id, input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
