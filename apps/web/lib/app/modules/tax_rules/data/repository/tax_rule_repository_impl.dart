import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import '../../domain/entity/tax_rule_list_item.dart';
import '../../domain/repository/tax_rule_repository.dart';
import '../datasource/tax_rule_datasource.dart';

class TaxRuleRepositoryImpl implements TaxRuleRepository {
  const TaxRuleRepositoryImpl({required this.datasource});

  final TaxRuleDatasource datasource;

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
  Future<Either<Failure, PagedResult<TaxRuleListItem>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, TaxRuleDraft>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, TaxRuleCatalogs>> getCatalogs() =>
      _guard(() => datasource.getCatalogs());

  @override
  Future<Either<Failure, Unit>> post(TaxRuleDraft draft) => _guard(() async {
        await datasource.post(draft);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> put(TaxRuleDraft draft) => _guard(() async {
        await datasource.put(draft);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
