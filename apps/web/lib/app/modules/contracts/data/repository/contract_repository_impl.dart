import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/contract_entity.dart';
import '../../domain/repository/contract_repository.dart';
import '../datasource/contract_datasource.dart';

class ContractRepositoryImpl implements ContractRepository {
  const ContractRepositoryImpl({required this.datasource});

  final ContractDatasource datasource;

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
  Future<Either<Failure, List<ContractListItem>>> getList() =>
      _guard(() => datasource.getList());

  @override
  Future<Either<Failure, ContractFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(ContractInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, ContractInput input) =>
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
