import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_entity.dart';
import '../repository/bank_repository.dart';

class BankPut {
  const BankPut({required this.repository});

  final BankRepository repository;

  Future<Either<Failure, Unit>> call(BankEntity bank) =>
      repository.put(bank);
}
