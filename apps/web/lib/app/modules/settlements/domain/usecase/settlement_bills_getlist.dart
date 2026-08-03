import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Página da carteira de títulos por [status] 'open'|'settled', [kind] e
/// filtro (paginação D3: [pageSize] null = config page_size da API — D4).
class SettlementBillsGetlist {
  const SettlementBillsGetlist({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, PagedResult<SettlementBill>>> call(
          String status, String kind, String filter,
          {int page = 1, int? pageSize}) =>
      repository.bills(status, kind, filter, page: page, pageSize: pageSize);
}
