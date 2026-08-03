import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_carrier.dart';
import '../repository/carrier_repository.dart';

/// Lista as Transportadoras da institution do usuário, uma PÁGINA por vez
/// (paginação D3).
class CarrierGetlist {
  const CarrierGetlist({required this.repository});

  final CarrierRepository repository;

  Future<Either<Failure, PagedResult<CarrierListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
