import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/module_entity.dart';
import '../repository/module_repository.dart';

class ModulePut {
  const ModulePut({required this.repository});

  final ModuleRepository repository;

  Future<Either<Failure, Unit>> call(ModuleEntity module) =>
      repository.put(module);
}
