import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Retorno com reembolso (evento T) — a factoring devolveu o cheque e
/// cobrou o dinheiro de volta. Só na factoring.
class CheckReturnRefund {
  const CheckReturnRefund({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckSettledResult>> call(
          int id, String dtRecord, int bankAccountId) =>
      repository.returnRefund(id, dtRecord, bankAccountId);
}
