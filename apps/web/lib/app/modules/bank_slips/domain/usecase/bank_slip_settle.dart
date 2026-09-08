import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Liquidação manual (evento L): 1 baixa para os N títulos sob UM
/// settled_code na conta congelada (D5).
class BankSlipSettle {
  const BankSlipSettle({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipSettleResult>> call(
          int id, double paidValue, String dtPayment) =>
      repository.settle(id, paidValue, dtPayment);
}
