import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_charge_agreement_entity.dart';
import '../repository/bank_charge_agreement_repository.dart';

/// Lista as Carteiras de Cobrança da institution (filtro REMOTO), uma
/// PÁGINA por vez (lista nova nasce paginada).
class BankChargeAgreementGetlist {
  const BankChargeAgreementGetlist({required this.repository});

  final BankChargeAgreementRepository repository;

  Future<Either<Failure, PagedResult<BankChargeAgreementListItem>>> call(
          String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
