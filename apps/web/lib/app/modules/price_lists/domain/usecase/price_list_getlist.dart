import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/price_list_entity.dart';
import '../repository/price_list_repository.dart';

/// Lista as Tabelas de Preço da institution (filtro REMOTO), uma PÁGINA
/// por vez (paginação obrigatória em lista nova).
class PriceListGetlist {
  const PriceListGetlist({required this.repository});

  final PriceListRepository repository;

  Future<Either<Failure, PagedResult<PriceListEntity>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
