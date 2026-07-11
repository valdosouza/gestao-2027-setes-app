import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/state_entity.dart';

/// Contrato do repositório de Estado (decisão 12: `Either<Failure, T>` via dartz).
abstract class StateRepository {
  Future<Either<Failure, List<StateEntity>>> getList(String filter);
  Future<Either<Failure, int>> post(StateEntity state);
  Future<Either<Failure, Unit>> put(StateEntity state);
  Future<Either<Failure, Unit>> delete(int id);
}
