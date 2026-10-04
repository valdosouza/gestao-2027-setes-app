import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/interface_entity.dart';
import '../repository/interface_repository.dart';

/// Lista as Interfaces (filtro por descrição), uma PÁGINA por vez
/// (paginação D3).
class InterfaceGetlist {
  const InterfaceGetlist({required this.repository});

  final InterfaceRepository repository;

  Future<Either<Failure, PagedResult<InterfaceEntity>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
