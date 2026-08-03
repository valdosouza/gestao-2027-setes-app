import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_account_entity.dart';
import '../repository/bank_account_repository.dart';

/// Lista as Contas Bancárias da institution (filtro REMOTO — D7), uma
/// PÁGINA por vez (paginação D3).
class BankAccountGetlist {
  const BankAccountGetlist({required this.repository});

  final BankAccountRepository repository;

  Future<Either<Failure, PagedResult<BankAccountListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
