import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/bank_charge_agreement_repository.dart';

class BankChargeAgreementDelete {
  const BankChargeAgreementDelete({required this.repository});

  final BankChargeAgreementRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
