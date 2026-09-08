import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_charge_agreement_entity.dart';
import '../repository/bank_charge_agreement_repository.dart';

class BankChargeAgreementPut {
  const BankChargeAgreementPut({required this.repository});

  final BankChargeAgreementRepository repository;

  Future<Either<Failure, Unit>> call(int id, BankChargeAgreementInput input) =>
      repository.put(id, input);
}
