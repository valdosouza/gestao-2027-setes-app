import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_collaborator.dart';
import '../repository/collaborator_repository.dart';

class CollaboratorGet {
  const CollaboratorGet({required this.repository});

  final CollaboratorRepository repository;

  Future<Either<Failure, ObjectCollaborator>> call(int id) =>
      repository.get(id);
}
