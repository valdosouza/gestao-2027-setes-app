import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/client_institution_entity.dart';

abstract class InstitutionInterfacesRepository {
  Future<Either<Failure, PagedResult<ClientInstitutionEntity>>> list(String filter, {int page, int? pageSize});
}
