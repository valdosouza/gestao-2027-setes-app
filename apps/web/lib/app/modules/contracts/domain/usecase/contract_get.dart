import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/contract_entity.dart';
import '../repository/contract_repository.dart';

/// Carrega o contrato COMPLETO para edição (a lista não traz itens).
class ContractGet {
  const ContractGet({required this.repository});

  final ContractRepository repository;

  Future<Either<Failure, ContractFull>> call(int id) =>
      repository.getById(id);
}
