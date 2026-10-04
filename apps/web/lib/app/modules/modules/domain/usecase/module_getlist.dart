import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/module_entity.dart';
import '../repository/module_repository.dart';

/// Lista os Módulos de Menu (filtro por descrição), uma PÁGINA por vez
/// (paginação D3).
class ModuleGetlist {
  const ModuleGetlist({required this.repository});

  final ModuleRepository repository;

  Future<Either<Failure, PagedResult<ModuleEntity>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
