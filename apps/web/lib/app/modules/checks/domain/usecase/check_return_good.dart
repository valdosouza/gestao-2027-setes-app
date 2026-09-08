import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/check_repository.dart';

/// Retorno bom (evento F) — pré-datado compensou na factoring, SEM
/// movimento financeiro; o cheque volta à custódia. Só na factoring.
/// Devolve o nº do evento gerado.
class CheckReturnGood {
  const CheckReturnGood({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, int>> call(int id, String? note) =>
      repository.returnGood(id, note);
}
