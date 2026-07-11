import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/state_repository.dart';

class StateDelete {
  const StateDelete({required this.repository});

  final StateRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
