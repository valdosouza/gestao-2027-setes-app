import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/module_repository.dart';

class ModuleDelete {
  const ModuleDelete({required this.repository});

  final ModuleRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
