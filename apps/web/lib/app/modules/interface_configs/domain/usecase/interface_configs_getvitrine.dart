import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../repository/interface_configs_repository.dart';

class InterfaceConfigsGetvitrine {
  const InterfaceConfigsGetvitrine({required this.repository});

  final InterfaceConfigsRepository repository;

  Future<Either<Failure, List<InterfaceVitrineEntity>>> call(String filter) =>
      repository.vitrine(filter);
}
