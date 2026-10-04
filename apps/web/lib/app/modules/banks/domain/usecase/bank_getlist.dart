import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/bank_entity.dart';
import '../repository/bank_repository.dart';

/// Lista os Bancos (filtro por número/descrição), uma PÁGINA por vez
/// (paginação D3).
class BankGetlist {
  const BankGetlist({required this.repository});

  final BankRepository repository;

  Future<Either<Failure, PagedResult<BankEntity>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
