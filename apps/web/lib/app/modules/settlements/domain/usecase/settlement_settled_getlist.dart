import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Página das baixas registradas (linha por EVENTO) — aba Baixados
/// (paginação D3: [pageSize] null = config page_size da API — D4).
class SettlementSettledGetlist {
  const SettlementSettledGetlist({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, PagedResult<SettlementSettled>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.settled(filter, page: page, pageSize: pageSize);
}
