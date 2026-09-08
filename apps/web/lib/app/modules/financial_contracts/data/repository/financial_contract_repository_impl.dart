import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/financial_contract_entity.dart';
import '../../domain/repository/financial_contract_repository.dart';
import '../datasource/financial_contract_datasource.dart';

class FinancialContractRepositoryImpl implements FinancialContractRepository {
  const FinancialContractRepositoryImpl({required this.datasource});

  final FinancialContractDatasource datasource;

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
  Future<Either<Failure, PagedResult<FinancialContractListItem>>> getList(
          String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, FinancialContractFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(FinancialContractInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, FinancialContractInput input) =>
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
