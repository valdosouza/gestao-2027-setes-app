import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_account_entity.dart';
import '../repository/bank_account_repository.dart';

class BankAccountGetlist {
  const BankAccountGetlist({required this.repository});

  final BankAccountRepository repository;

  Future<Either<Failure, List<BankAccountListItem>>> call() =>
      repository.getList();
}
