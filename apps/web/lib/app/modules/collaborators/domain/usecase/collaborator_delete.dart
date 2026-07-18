import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/collaborator_repository.dart';

class CollaboratorDelete {
  const CollaboratorDelete({required this.repository});

  final CollaboratorRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
