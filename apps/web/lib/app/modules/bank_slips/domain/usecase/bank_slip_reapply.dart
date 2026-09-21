import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Reaplica o efeito de uma voz do banco (R/C/V) que a nossa regra recusou
/// na hora (D-I10 → D-I25): POST /api/bank-slips/:id/reapply. Ato MANUAL —
/// a API não reaplica sozinha; recusa de novo volta como Failure legível.
class BankSlipReapply {
  const BankSlipReapply({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipReapplyResult>> call(
          int id, int attempt, int event) =>
      repository.reapply(id, attempt, event);
}
