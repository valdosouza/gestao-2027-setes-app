import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_salesman.dart';
import '../repository/salesman_repository.dart';

/// Lista os Vendedores da institution do usuário, uma PÁGINA por vez
/// (paginação D3).
class SalesmanGetlist {
  const SalesmanGetlist({required this.repository});

  final SalesmanRepository repository;

  Future<Either<Failure, PagedResult<SalesmanListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
