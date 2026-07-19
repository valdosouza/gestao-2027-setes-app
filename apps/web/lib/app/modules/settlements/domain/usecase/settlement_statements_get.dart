import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Extrato banco/caixa do filtro — totais e SALDO vêm prontos da API.
class SettlementStatementsGet {
  const SettlementStatementsGet({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, SettlementStatementReport>> call(
          int bankAccountId, String? dtFrom, String? dtTo) =>
      repository.statements(bankAccountId, dtFrom, dtTo);
}
