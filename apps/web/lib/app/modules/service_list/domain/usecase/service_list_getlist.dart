import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_list_entity.dart';
import '../repository/service_list_repository.dart';

/// Lista os itens da LC 116 (filtro por item/descrição), uma PÁGINA por vez
/// (paginação D3).
class ServiceListGetlist {
  const ServiceListGetlist({required this.repository});

  final ServiceListRepository repository;

  Future<Either<Failure, PagedResult<ServiceListEntity>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
