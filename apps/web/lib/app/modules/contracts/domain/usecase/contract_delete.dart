import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/contract_repository.dart';

class ContractDelete {
  const ContractDelete({required this.repository});

  final ContractRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
