import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/users/entity/user_entity.dart';
import '../repository/user_repository.dart';

class UserPost {
  const UserPost({required this.repository});

  final UserRepository repository;

  Future<Either<Failure, int>> call(UserEntity user) => repository.post(user);
}
