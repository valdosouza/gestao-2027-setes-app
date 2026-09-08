import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Página da lista de boletos por [status] derivado e filtro (paginação
/// D3: [pageSize] null = config page_size da API — D4).
class BankSlipGetlist {
  const BankSlipGetlist({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, PagedResult<BankSlipListRow>>> call(
          String status, String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(status, filter, page: page, pageSize: pageSize);
}
