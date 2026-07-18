import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_collaborator.dart';
import '../repository/collaborator_repository.dart';

class CollaboratorPost {
  const CollaboratorPost({required this.repository});

  final CollaboratorRepository repository;

  Future<Either<Failure, CollaboratorPostResult>> call(
          ObjectCollaborator collaborator) =>
      repository.post(collaborator);
}
