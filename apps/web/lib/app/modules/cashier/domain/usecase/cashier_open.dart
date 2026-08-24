import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cashier_entity.dart';
import '../repository/cashier_repository.dart';

/// Abre uma sessão nova (dia+usuário+terminal 0) — 409
/// CASHIER_ALREADY_OPEN se já existir uma aberta.
class CashierOpen {
  const CashierOpen({required this.repository});

  final CashierRepository repository;

  Future<Either<Failure, CashierRow>> call() => repository.open();
}
