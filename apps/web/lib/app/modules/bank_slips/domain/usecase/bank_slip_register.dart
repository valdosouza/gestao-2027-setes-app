import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Apresenta o boleto ao BANCO pelo canal API da conta (Onda 2 — D-I5…D-I7):
/// POST /api/bank-slips/:id/register. A emissão no banco é assíncrona — o
/// que volta é a apresentação (attempt + codigoSolicitacao).
class BankSlipRegister {
  const BankSlipRegister({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipRegisterResult>> call(int id) =>
      repository.register(id);
}
