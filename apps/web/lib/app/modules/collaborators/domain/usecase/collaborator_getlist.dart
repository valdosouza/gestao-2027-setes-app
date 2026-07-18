import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_collaborator.dart';
import '../repository/collaborator_repository.dart';

class CollaboratorGetlist {
  const CollaboratorGetlist({required this.repository});

  final CollaboratorRepository repository;

  Future<Either<Failure, List<CollaboratorListItem>>> call(String filter) =>
      repository.getList(filter);
}
