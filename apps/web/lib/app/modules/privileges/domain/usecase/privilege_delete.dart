import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/privilege_repository.dart';

class PrivilegeDelete {
  const PrivilegeDelete({required this.repository});

  final PrivilegeRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
