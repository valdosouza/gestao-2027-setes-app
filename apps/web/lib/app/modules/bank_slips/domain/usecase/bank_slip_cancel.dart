import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/bank_slip_repository.dart';

/// Cancelamento (evento C) — libera os títulos para reemissão/outra forma.
/// Devolve o nº do evento gerado.
class BankSlipCancel {
  const BankSlipCancel({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, int>> call(int id, String? note) =>
      repository.cancel(id, note);
}
