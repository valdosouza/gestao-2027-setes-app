import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/interface_entity.dart';
import '../repository/interface_repository.dart';

class InterfaceGetlist {
  const InterfaceGetlist({required this.repository});

  final InterfaceRepository repository;

  Future<Either<Failure, List<InterfaceEntity>>> call(String filter) =>
      repository.getList(filter);
}
