import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';

/// Contrato do repositório do painel de configurações (Either/dartz).
abstract class InterfaceConfigsRepository {
  Future<Either<Failure, List<InterfaceVitrineEntity>>> vitrine(String filter);
  Future<Either<Failure, List<InterfaceConfigEntity>>> configs(int interfaceId);
  Future<Either<Failure, Unit>> saveValue({
    required int interfaceId,
    required String name,
    required String? content,
    required bool asUser,
  });
}
