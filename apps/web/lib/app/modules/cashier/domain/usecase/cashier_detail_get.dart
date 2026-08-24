import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cashier_entity.dart';
import '../repository/cashier_repository.dart';

/// Saldo derivado + registrado por forma de pagamento — recarregado após
/// TODA ação (abrir/retirar/fechar nunca soma localmente).
class CashierDetailGet {
  const CashierDetailGet({required this.repository});

  final CashierRepository repository;

  Future<Either<Failure, CashierDetail>> call(int id) =>
      repository.detail(id);
}
