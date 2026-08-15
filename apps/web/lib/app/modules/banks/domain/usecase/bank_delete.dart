import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/bank_repository.dart';

class BankDelete {
  const BankDelete({required this.repository});

  final BankRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
