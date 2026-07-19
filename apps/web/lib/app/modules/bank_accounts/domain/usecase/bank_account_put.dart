import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_account_entity.dart';
import '../repository/bank_account_repository.dart';

class BankAccountPut {
  const BankAccountPut({required this.repository});

  final BankAccountRepository repository;

  Future<Either<Failure, Unit>> call(int id, BankAccountInput input) =>
      repository.put(id, input);
}
