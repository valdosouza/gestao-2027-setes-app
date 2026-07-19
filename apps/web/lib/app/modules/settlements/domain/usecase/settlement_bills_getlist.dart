import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Carteira de títulos por [status] 'open'|'settled', [kind] e filtro.
class SettlementBillsGetlist {
  const SettlementBillsGetlist({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, List<SettlementBill>>> call(
          String status, String kind, String filter) =>
      repository.bills(status, kind, filter);
}
