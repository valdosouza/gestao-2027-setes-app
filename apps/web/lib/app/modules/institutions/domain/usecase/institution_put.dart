import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_institution.dart';
import '../repository/institution_repository.dart';

class InstitutionPut {
  const InstitutionPut({required this.repository});

  final InstitutionRepository repository;

  Future<Either<Failure, Unit>> call(ObjectInstitution institution) =>
      repository.put(institution);
}
