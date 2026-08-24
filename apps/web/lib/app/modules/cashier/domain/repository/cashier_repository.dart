import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cashier_entity.dart';

/// Contrato do repositório do Caixa (Either/dartz) — operações da SESSÃO:
/// consultar/abrir, detalhe com saldo derivado, retirada/transferência e
/// fechamento com relatório.
abstract class CashierRepository {
  Future<Either<Failure, CashierRow?>> current();
  Future<Either<Failure, CashierRow>> open();
  Future<Either<Failure, CashierDetail>> detail(int id);
  Future<Either<Failure, CashierWithdrawResult>> withdraw(
      int id, CashierWithdrawInput input);
  Future<Either<Failure, CashierCloseResult>> close(
      int id, CashierCloseInput input);
}
