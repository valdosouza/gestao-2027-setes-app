import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/bank_account_entity.dart';
import '../repository/bank_account_repository.dart';

/// Lista as Contas Bancárias da institution (filtro REMOTO — D7), uma
/// PÁGINA por vez (paginação D3).
class BankAccountGetlist {
  const BankAccountGetlist({required this.repository});

  final BankAccountRepository repository;

  Future<Either<Failure, PagedResult<BankAccountListItem>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
