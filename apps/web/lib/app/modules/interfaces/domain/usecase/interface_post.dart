import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/interface_entity.dart';
import '../repository/interface_repository.dart';

class InterfacePost {
  const InterfacePost({required this.repository});

  final InterfaceRepository repository;

  Future<Either<Failure, int>> call(InterfaceEntity entity) =>
      repository.post(entity);
}
