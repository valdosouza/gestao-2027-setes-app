import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/settlement_entity.dart';
import '../repository/settlement_repository.dart';

/// Baixas registradas (linha por EVENTO) para a aba Baixados.
class SettlementSettledGetlist {
  const SettlementSettledGetlist({required this.repository});

  final SettlementRepository repository;

  Future<Either<Failure, List<SettlementSettled>>> call(String filter) =>
      repository.settled(filter);
}
