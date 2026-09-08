import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_charge_agreement_entity.dart';

/// Contrato do repositório de Carteiras de Cobrança (Either/dartz). O
/// lookup de conta corrente fica FORA do repositório — a page toca o
/// datasource dedicado diretamente (molde bank_accounts/financial_contracts).
abstract class BankChargeAgreementRepository {
  Future<Either<Failure, PagedResult<BankChargeAgreementListItem>>> getList(
      String filter,
      {int page, int? pageSize});
  Future<Either<Failure, BankChargeAgreementFull>> getById(int id);
  Future<Either<Failure, int>> post(BankChargeAgreementInput input);
  Future<Either<Failure, Unit>> put(int id, BankChargeAgreementInput input);
  Future<Either<Failure, Unit>> delete(int id);
}
