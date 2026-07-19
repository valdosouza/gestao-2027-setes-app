import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/contract_entity.dart';
import '../repository/contract_repository.dart';

class ContractPost {
  const ContractPost({required this.repository});

  final ContractRepository repository;

  Future<Either<Failure, int>> call(ContractInput input) =>
      repository.post(input);
}
