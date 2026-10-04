import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../../../../shared/users/entity/user_entity.dart';
import '../repository/user_repository.dart';

/// Lista os Usuários (filtro por nome/email), uma PÁGINA por vez
/// (paginação D3).
class UserGetlist {
  const UserGetlist({required this.repository});

  final UserRepository repository;

  Future<Either<Failure, PagedResult<UserListItem>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
