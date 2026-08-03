import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/state_entity.dart';
import '../repository/state_repository.dart';

/// Lista os Estados (filtro por nome/UF), uma PÁGINA por vez (paginação D3).
class StateGetlist {
  const StateGetlist({required this.repository});

  final StateRepository repository;

  Future<Either<Failure, PagedResult<StateEntity>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
