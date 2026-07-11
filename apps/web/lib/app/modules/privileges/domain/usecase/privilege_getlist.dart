import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/privilege_entity.dart';
import '../repository/privilege_repository.dart';

class PrivilegeGetlist {
  const PrivilegeGetlist({required this.repository});

  final PrivilegeRepository repository;

  Future<Either<Failure, List<PrivilegeEntity>>> call(String filter) =>
      repository.getList(filter);
}
