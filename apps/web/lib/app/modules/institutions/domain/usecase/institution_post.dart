import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_institution.dart';
import '../repository/institution_repository.dart';

class InstitutionPost {
  const InstitutionPost({required this.repository});

  final InstitutionRepository repository;

  Future<Either<Failure, int>> call(ObjectInstitution institution) =>
      repository.post(institution);
}
