import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cashier_entity.dart';
import '../repository/cashier_repository.dart';

/// Fechamento — conferência registrado×contado por forma de pagamento +
/// transferência opcional do saldo total; devolve o RELATÓRIO completo.
class CashierClose {
  const CashierClose({required this.repository});

  final CashierRepository repository;

  Future<Either<Failure, CashierCloseResult>> call(
          int id, CashierCloseInput input) =>
      repository.close(id, input);
}
