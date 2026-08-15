import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/module_entity.dart';
import '../repository/module_repository.dart';

/// Interfaces ELEGÍVEIS ao vínculo do menu (GET /api/modules/interface-lookup):
/// alimenta o picker "Adicionar tela" e os rótulos da seção "Telas do módulo".
class ModuleInterfaceOptions {
  const ModuleInterfaceOptions({required this.repository});

  final ModuleRepository repository;

  Future<Either<Failure, List<ModuleInterfaceOption>>> call() =>
      repository.interfaceOptions();
}
