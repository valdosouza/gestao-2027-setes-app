import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Desconta o cheque na factoring (evento D) — crédito pelo valor de face
/// menos a taxa/ágio digitado. Só em custódia.
class CheckDiscount {
  const CheckDiscount({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckSettledResult>> call(int id, String dtRecord,
          int factoringEntityId, int bankAccountId, double feeValue) =>
      repository.discount(
          id, dtRecord, factoringEntityId, bankAccountId, feeValue);
}
