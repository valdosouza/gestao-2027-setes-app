import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_collaborator.dart';

/// Contrato do repositório de Colaborador (Either/dartz).
abstract class CollaboratorRepository {
  Future<Either<Failure, List<CollaboratorListItem>>> getList(String filter);
  Future<Either<Failure, ObjectCollaborator>> get(int id);
  Future<Either<Failure, CollaboratorPostResult>> post(
      ObjectCollaborator collaborator);
  Future<Either<Failure, Unit>> put(ObjectCollaborator collaborator);
  Future<Either<Failure, Unit>> delete(int id);
}
