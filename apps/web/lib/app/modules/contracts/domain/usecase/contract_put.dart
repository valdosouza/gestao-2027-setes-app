import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/contract_entity.dart';
import '../repository/contract_repository.dart';

class ContractPut {
  const ContractPut({required this.repository});

  final ContractRepository repository;

  Future<Either<Failure, Unit>> call(int id, ContractInput input) =>
      repository.put(id, input);
}
