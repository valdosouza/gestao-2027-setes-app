import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/privilege_entity.dart';
import '../repository/privilege_repository.dart';

class PrivilegePut {
  const PrivilegePut({required this.repository});

  final PrivilegeRepository repository;

  Future<Either<Failure, Unit>> call(PrivilegeEntity privilege) =>
      repository.put(privilege);
}
