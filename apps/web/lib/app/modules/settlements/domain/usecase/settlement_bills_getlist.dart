import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Página da carteira de títulos por [status] 'open'|'settled', [kind] e
/// filtro (paginação D3: [pageSize] null = config page_size da API — D4).
/// [criteria] = pesquisa avançada dos títulos (D-BA1) — soma em E.
class SettlementBillsGetlist {
  const SettlementBillsGetlist({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, PagedResult<SettlementBill>>> call(
          String status, String kind, String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.bills(status, kind, filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
