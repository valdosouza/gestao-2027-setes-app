import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/privilege_entity.dart';
import '../repository/privilege_repository.dart';

/// Lista os Privilégios (filtro por descrição), uma PÁGINA por vez
/// (paginação D3).
class PrivilegeGetlist {
  const PrivilegeGetlist({required this.repository});

  final PrivilegeRepository repository;

  Future<Either<Failure, PagedResult<PrivilegeEntity>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
