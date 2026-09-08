import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/financial_contract_entity.dart';
import '../repository/financial_contract_repository.dart';

/// Lista os Contratos Financeiros da institution (filtro REMOTO), uma
/// PÁGINA por vez (lista nova nasce paginada).
class FinancialContractGetlist {
  const FinancialContractGetlist({required this.repository});

  final FinancialContractRepository repository;

  Future<Either<Failure, PagedResult<FinancialContractListItem>>> call(
          String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
