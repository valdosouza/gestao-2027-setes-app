import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_charge_agreement_entity.dart';
import '../repository/bank_charge_agreement_repository.dart';

/// Carrega a carteira COMPLETA (GET /:id) para edição — a lista não traz
/// encargos/instrução/protesto.
class BankChargeAgreementGet {
  const BankChargeAgreementGet({required this.repository});

  final BankChargeAgreementRepository repository;

  Future<Either<Failure, BankChargeAgreementFull>> call(int id) =>
      repository.getById(id);
}
