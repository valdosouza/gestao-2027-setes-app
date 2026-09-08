import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Estorno da liquidação (evento X) — inverte as baixas do settled_code e
/// reabre o boleto (D10).
class BankSlipReverse {
  const BankSlipReverse({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipReverseResult>> call(int id, String reason) =>
      repository.reverse(id, reason);
}
