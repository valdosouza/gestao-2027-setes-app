import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_collaborator.dart';
import '../repository/collaborator_repository.dart';

/// Lista os Colaboradores da institution do usuário, uma PÁGINA por vez
/// (paginação D3).
class CollaboratorGetlist {
  const CollaboratorGetlist({required this.repository});

  final CollaboratorRepository repository;

  Future<Either<Failure, PagedResult<CollaboratorListItem>>> call(
          String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
