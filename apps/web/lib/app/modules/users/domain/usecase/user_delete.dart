import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/user_repository.dart';

class UserDelete {
  const UserDelete({required this.repository});

  final UserRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
