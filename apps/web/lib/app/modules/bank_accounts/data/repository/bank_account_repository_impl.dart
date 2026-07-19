import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/bank_account_entity.dart';
import '../../domain/repository/bank_account_repository.dart';
import '../datasource/bank_account_datasource.dart';

class BankAccountRepositoryImpl implements BankAccountRepository {
  const BankAccountRepositoryImpl({required this.datasource});

  final BankAccountDatasource datasource;

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
  Future<Either<Failure, List<BankAccountListItem>>> getList() =>
      _guard(() => datasource.getList());

  @override
  Future<Either<Failure, BankAccountFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(BankAccountInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, BankAccountInput input) =>
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
