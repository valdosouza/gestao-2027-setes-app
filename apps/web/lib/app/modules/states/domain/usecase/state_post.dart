import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/state_entity.dart';
import '../repository/state_repository.dart';

class StatePost {
  const StatePost({required this.repository});

  final StateRepository repository;

  Future<Either<Failure, int>> call(StateEntity state) =>
      repository.post(state);
}
