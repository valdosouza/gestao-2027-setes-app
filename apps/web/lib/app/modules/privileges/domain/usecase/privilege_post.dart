import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/privilege_entity.dart';
import '../repository/privilege_repository.dart';

class PrivilegePost {
  const PrivilegePost({required this.repository});

  final PrivilegeRepository repository;

  Future<Either<Failure, int>> call(PrivilegeEntity privilege) =>
      repository.post(privilege);
}
