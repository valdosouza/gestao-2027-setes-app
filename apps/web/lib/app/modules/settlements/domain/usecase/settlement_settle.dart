import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Baixa em LOTE: N títulos → 1 settled_code → 1 movimento (N:1).
class SettlementSettle {
  const SettlementSettle({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, SettlementBatchResult>> call(
          SettlementBatchInput input) =>
      repository.settle(input);
}
