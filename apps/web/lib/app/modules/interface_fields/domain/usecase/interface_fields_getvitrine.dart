import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../../../../shared/search/search_criterion.dart';
import '../repository/interface_fields_repository.dart';

/// Vitrine de interfaces do painel de campos, uma PÁGINA por vez
/// (paginação D3).
class InterfaceFieldsGetvitrine {
  const InterfaceFieldsGetvitrine({required this.repository});

  final InterfaceFieldsRepository repository;

  Future<Either<Failure, PagedResult<InterfaceVitrineEntity>>> call(
          String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.vitrine(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
