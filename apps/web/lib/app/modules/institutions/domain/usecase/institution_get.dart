import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_institution.dart';
import '../repository/institution_repository.dart';

/// Busca o Estabelecimento COMPLETO (cadeia fiscal inteira) para edição.
class InstitutionGet {
  const InstitutionGet({required this.repository});

  final InstitutionRepository repository;

  Future<Either<Failure, ObjectInstitution>> call(int id) =>
      repository.get(id);
}
