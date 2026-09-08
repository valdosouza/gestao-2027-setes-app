import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Devolve o cheque (evento V) — sem fundos; cria um título NOVO contra o
/// cliente que entregou o cheque. Só em custódia.
class CheckReturnToOrigin {
  const CheckReturnToOrigin({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckReturnResult>> call(
          int id, String dtRecord, String? note) =>
      repository.returnToOrigin(id, dtRecord, note);
}
