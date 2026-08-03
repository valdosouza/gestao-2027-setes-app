import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_institution.dart';
import '../repository/institution_repository.dart';

/// Lista os Estabelecimentos (filtro por nome/fantasia), uma PÁGINA por
/// vez (paginação D3).
class InstitutionGetlist {
  const InstitutionGetlist({required this.repository});

  final InstitutionRepository repository;

  Future<Either<Failure, PagedResult<InstitutionListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
