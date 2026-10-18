import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/client_institution_entity.dart';
import '../repository/institution_interfaces_repository.dart';

class InstitutionInterfacesGetlist {
  const InstitutionInterfacesGetlist({required this.repository});

  final InstitutionInterfacesRepository repository;

  Future<Either<Failure, PagedResult<ClientInstitutionEntity>>> call(String filter, {int page = 1, int? pageSize}) =>
      repository.list(filter, page: page, pageSize: pageSize);
}
