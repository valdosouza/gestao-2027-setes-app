import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Emissão do boleto (evento E) — 1 título ou N do mesmo cliente (D9).
class BankSlipIssue {
  const BankSlipIssue({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipIssueResult>> call(
          BankSlipIssueInput input) =>
      repository.issue(input);
}
