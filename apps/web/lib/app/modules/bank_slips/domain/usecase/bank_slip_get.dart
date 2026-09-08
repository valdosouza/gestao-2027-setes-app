import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Detalhe do boleto (cabeçalho congelado + títulos + eventos).
class BankSlipGet {
  const BankSlipGet({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipFull>> call(int id) => repository.getOne(id);
}
