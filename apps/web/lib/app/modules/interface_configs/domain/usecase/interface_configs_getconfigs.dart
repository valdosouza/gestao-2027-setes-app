import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../repository/interface_configs_repository.dart';

class InterfaceConfigsGetconfigs {
  const InterfaceConfigsGetconfigs({required this.repository});

  final InterfaceConfigsRepository repository;

  Future<Either<Failure, List<InterfaceConfigEntity>>> call(int interfaceId) =>
      repository.configs(interfaceId);
}
