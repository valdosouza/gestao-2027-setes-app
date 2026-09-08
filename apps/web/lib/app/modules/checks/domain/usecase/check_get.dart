import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Detalhe do cheque (cabeçalho + história completa de eventos).
class CheckGet {
  const CheckGet({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckFull>> call(int id) => repository.getOne(id);
}
