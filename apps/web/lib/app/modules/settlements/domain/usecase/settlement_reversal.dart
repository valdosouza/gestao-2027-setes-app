import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Estorno IMUTÁVEL da baixa vigente (lançamento inverso status 'R' +
/// marcação 'E' no original) — 409 da API = baixa não vigente.
class SettlementReversal {
  const SettlementReversal({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, SettlementReversalResult>> call(
          int orderId, int parcel, int event, String reason) =>
      repository.reversal(orderId, parcel, event, reason);
}
