import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/interface_entity.dart';
import '../repository/interface_repository.dart';

class InterfacePut {
  const InterfacePut({required this.repository});

  final InterfaceRepository repository;

  Future<Either<Failure, Unit>> call(InterfaceEntity entity) =>
      repository.put(entity);
}
