import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_entity.dart';

/// Contrato do repositório de Banco (decisão 12: `Either<Failure, T>` via dartz).
abstract class BankRepository {
  Future<Either<Failure, PagedResult<BankEntity>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, int>> post(BankEntity bank);
  Future<Either<Failure, Unit>> put(BankEntity bank);
  Future<Either<Failure, Unit>> delete(int id);
}
