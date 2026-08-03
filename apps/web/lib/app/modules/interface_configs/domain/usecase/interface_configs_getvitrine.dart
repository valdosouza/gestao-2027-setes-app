import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../repository/interface_configs_repository.dart';

/// Vitrine de interfaces do painel de configurações, uma PÁGINA por vez
/// (paginação D3).
class InterfaceConfigsGetvitrine {
  const InterfaceConfigsGetvitrine({required this.repository});

  final InterfaceConfigsRepository repository;

  Future<Either<Failure, PagedResult<InterfaceVitrineEntity>>> call(
          String filter,
          {int page = 1, int? pageSize}) =>
      repository.vitrine(filter, page: page, pageSize: pageSize);
}
