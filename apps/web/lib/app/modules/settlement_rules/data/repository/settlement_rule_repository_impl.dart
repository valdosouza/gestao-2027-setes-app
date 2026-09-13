import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/settlement_rule_entity.dart';
import '../../domain/repository/settlement_rule_repository.dart';
import '../datasource/settlement_rule_datasource.dart';

class SettlementRuleRepositoryImpl implements SettlementRuleRepository {
  const SettlementRuleRepositoryImpl({required this.datasource});

  final SettlementRuleDatasource datasource;

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
  Future<Either<Failure, PagedResult<SettlementRuleListItem>>> getList(
          String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, SettlementRuleFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(SettlementRuleInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, SettlementRuleInput input) =>
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
