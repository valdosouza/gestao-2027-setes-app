import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/bank_account_repository.dart';

class BankAccountDelete {
  const BankAccountDelete({required this.repository});

  final BankAccountRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
