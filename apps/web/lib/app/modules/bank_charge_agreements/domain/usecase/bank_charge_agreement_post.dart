import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_charge_agreement_entity.dart';
import '../repository/bank_charge_agreement_repository.dart';

class BankChargeAgreementPost {
  const BankChargeAgreementPost({required this.repository});

  final BankChargeAgreementRepository repository;

  Future<Either<Failure, int>> call(BankChargeAgreementInput input) =>
      repository.post(input);
}
