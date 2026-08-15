import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_entity.dart';
import '../repository/bank_repository.dart';

class BankPost {
  const BankPost({required this.repository});

  final BankRepository repository;

  Future<Either<Failure, int>> call(BankEntity bank) =>
      repository.post(bank);
}
