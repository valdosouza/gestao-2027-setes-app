import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/module_entity.dart';

/// Contrato do repositório de Módulo de Menu (decisão 12: Either via dartz).
abstract class ModuleRepository {
  Future<Either<Failure, PagedResult<ModuleEntity>>> getList(String filter,
      {int page, int? pageSize});

  /// Interfaces elegíveis ao vínculo (picker + rótulos da seção de telas).
  Future<Either<Failure, List<ModuleInterfaceOption>>> interfaceOptions();
  Future<Either<Failure, int>> post(ModuleEntity module);
  Future<Either<Failure, Unit>> put(ModuleEntity module);
  Future<Either<Failure, Unit>> delete(int id);
}
