import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/cfop_entity.dart';
import '../repository/cfop_repository.dart';

/// Lista os CFOPs (filtro por código/descrição), uma PÁGINA por vez
/// (paginação D3).
class CfopGetlist {
  const CfopGetlist({required this.repository});

  final CfopRepository repository;

  Future<Either<Failure, PagedResult<CfopEntity>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
