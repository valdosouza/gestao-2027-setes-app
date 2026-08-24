import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cashier_entity.dart';
import '../repository/cashier_repository.dart';

/// Sessão ABERTA do usuário corrente, ou null (nenhuma hoje) — 1ª consulta
/// ao entrar na tela.
class CashierCurrentGet {
  const CashierCurrentGet({required this.repository});

  final CashierRepository repository;

  Future<Either<Failure, CashierRow?>> call() => repository.current();
}
