import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Página da lista de cheques por [status] derivado e filtro (paginação:
/// [pageSize] null = config page_size da API). [criteria] = pesquisa
/// avançada (D-BA1) — soma em E com os demais.
class CheckGetlist {
  const CheckGetlist({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, PagedResult<CheckListRow>>> call(
          String status, String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(status, filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
