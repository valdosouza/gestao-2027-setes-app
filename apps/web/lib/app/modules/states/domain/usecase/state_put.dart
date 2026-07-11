import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/state_entity.dart';
import '../repository/state_repository.dart';

class StatePut {
  const StatePut({required this.repository});

  final StateRepository repository;

  Future<Either<Failure, Unit>> call(StateEntity state) =>
      repository.put(state);
}
