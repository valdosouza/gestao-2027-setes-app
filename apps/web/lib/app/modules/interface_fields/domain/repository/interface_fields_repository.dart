import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../entity/interface_vitrine_entity.dart';

/// Contrato do repositório do painel de campos (decisão 12: Either/dartz).
abstract class InterfaceFieldsRepository {
  Future<Either<Failure, List<InterfaceVitrineEntity>>> vitrine(String filter);
  Future<Either<Failure, List<FieldConfigEntity>>> fields(int interfaceId);
  Future<Either<Failure, Unit>> saveField({
    required int interfaceId,
    required String fieldName,
    String? caption,
    bool required,
    String? mask,
  });
}
