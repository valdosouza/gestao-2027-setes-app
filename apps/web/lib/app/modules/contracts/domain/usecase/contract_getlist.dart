import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/contract_entity.dart';
import '../repository/contract_repository.dart';

class ContractGetlist {
  const ContractGetlist({required this.repository});

  final ContractRepository repository;

  Future<Either<Failure, List<ContractListItem>>> call() =>
      repository.getList();
}
