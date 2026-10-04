import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/contract_entity.dart';
import '../repository/contract_repository.dart';

/// Lista os Contratos da institution (filtro REMOTO por nome do cliente —
/// D7), uma PÁGINA por vez (paginação D3).
class ContractGetlist {
  const ContractGetlist({required this.repository});

  final ContractRepository repository;

  Future<Either<Failure, PagedResult<ContractListItem>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
