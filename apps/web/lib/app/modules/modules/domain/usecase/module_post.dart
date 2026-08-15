import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/module_entity.dart';
import '../repository/module_repository.dart';

class ModulePost {
  const ModulePost({required this.repository});

  final ModuleRepository repository;

  Future<Either<Failure, int>> call(ModuleEntity module) =>
      repository.post(module);
}
