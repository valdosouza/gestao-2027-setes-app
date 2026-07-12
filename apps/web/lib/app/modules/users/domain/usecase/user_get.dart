import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/users/entity/user_entity.dart';
import '../repository/user_repository.dart';

class UserGet {
  const UserGet({required this.repository});

  final UserRepository repository;

  Future<Either<Failure, UserEntity>> call(int id) => repository.get(id);
}
