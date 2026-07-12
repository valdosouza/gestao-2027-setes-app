import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/users/entity/user_entity.dart';
import '../repository/user_repository.dart';

class UserGetlist {
  const UserGetlist({required this.repository});

  final UserRepository repository;

  Future<Either<Failure, List<UserListItem>>> call(String filter) =>
      repository.getList(filter);
}
