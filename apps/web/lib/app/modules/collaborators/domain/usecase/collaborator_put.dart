import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_collaborator.dart';
import '../repository/collaborator_repository.dart';

class CollaboratorPut {
  const CollaboratorPut({required this.repository});

  final CollaboratorRepository repository;

  Future<Either<Failure, Unit>> call(ObjectCollaborator collaborator) =>
      repository.put(collaborator);
}
