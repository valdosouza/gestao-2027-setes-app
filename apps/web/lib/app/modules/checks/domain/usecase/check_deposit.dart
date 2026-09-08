import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Deposita o cheque (evento B) — cofre → banco. Só em custódia.
class CheckDeposit {
  const CheckDeposit({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckSettledResult>> call(
          int id, String dtRecord, int bankAccountId) =>
      repository.deposit(id, dtRecord, bankAccountId);
}
