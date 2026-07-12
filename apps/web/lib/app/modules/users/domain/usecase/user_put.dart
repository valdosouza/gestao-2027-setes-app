import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/users/entity/user_entity.dart';
import '../repository/user_repository.dart';

class UserPut {
  const UserPut({required this.repository});

  final UserRepository repository;

  Future<Either<Failure, Unit>> call(UserEntity user) => repository.put(user);
}
