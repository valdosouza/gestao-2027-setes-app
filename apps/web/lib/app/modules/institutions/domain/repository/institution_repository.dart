import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_institution.dart';

/// Contrato do repositório de Estabelecimento (decisão 12: Either via dartz).
abstract class InstitutionRepository {
  Future<Either<Failure, PagedResult<InstitutionListItem>>> getList(
      String filter,
      {int page,
      int? pageSize});
  Future<Either<Failure, ObjectInstitution>> get(int id);
  Future<Either<Failure, int>> post(ObjectInstitution institution);
  Future<Either<Failure, Unit>> put(ObjectInstitution institution);
  Future<Either<Failure, Unit>> delete(int id);
}
