import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Página da lista de cheques por [status] derivado e filtro (paginação:
/// [pageSize] null = config page_size da API).
class CheckGetlist {
  const CheckGetlist({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, PagedResult<CheckListRow>>> call(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(status, filter, page: page, pageSize: pageSize);
}
