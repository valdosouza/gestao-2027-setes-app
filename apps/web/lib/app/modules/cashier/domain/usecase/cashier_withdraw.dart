import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cashier_entity.dart';
import '../repository/cashier_repository.dart';

/// Retirada simples ou transferência (com [CashierWithdrawInput.
/// destinationBankAccountId]) do caixa aberto.
class CashierWithdraw {
  const CashierWithdraw({required this.repository});

  final CashierRepository repository;

  Future<Either<Failure, CashierWithdrawResult>> call(
          int id, CashierWithdrawInput input) =>
      repository.withdraw(id, input);
}
