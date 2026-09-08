import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Estorna o [event] mais recente do cheque (evento X) — a API recusa
/// (409 CHECK_ALREADY_MOVED) se não for o último; alguns kinds não são
/// reversíveis (409 CHECK_EVENT_NOT_REVERSIBLE), tratado pelo pipeline
/// padrão de erro.
class CheckReverse {
  const CheckReverse({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckReverseResult>> call(
          int id, int event, String reason) =>
      repository.reverse(id, event, reason);
}
