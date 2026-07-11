import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/state_entity.dart';
import '../repository/state_repository.dart';

class StateGetlist {
  const StateGetlist({required this.repository});

  final StateRepository repository;

  Future<Either<Failure, List<StateEntity>>> call(String filter) =>
      repository.getList(filter);
}
