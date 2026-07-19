import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_account_entity.dart';

/// Contrato do repositório de Contas Bancárias (Either/dartz).
abstract class BankAccountRepository {
  Future<Either<Failure, List<BankAccountListItem>>> getList();
  Future<Either<Failure, BankAccountFull>> getById(int id);
  Future<Either<Failure, int>> post(BankAccountInput input);
  Future<Either<Failure, Unit>> put(int id, BankAccountInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
