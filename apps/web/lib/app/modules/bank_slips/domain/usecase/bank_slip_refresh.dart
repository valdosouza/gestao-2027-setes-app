import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Consulta o banco sobre a apresentação vigente e grava a VOZ dele (Onda 2 —
/// D-I9): POST /api/bank-slips/:id/refresh. RECEBIDO liquida o boleto pela
/// peça; a mesma situação duas vezes não gera nada (idempotente).
class BankSlipRefresh {
  const BankSlipRefresh({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipRefreshResult>> call(int id) =>
      repository.refresh(id);
}
