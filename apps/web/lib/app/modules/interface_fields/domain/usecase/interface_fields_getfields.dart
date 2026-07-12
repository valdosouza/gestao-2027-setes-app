import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../repository/interface_fields_repository.dart';

class InterfaceFieldsGetfields {
  const InterfaceFieldsGetfields({required this.repository});

  final InterfaceFieldsRepository repository;

  Future<Either<Failure, List<FieldConfigEntity>>> call(int interfaceId) =>
      repository.fields(interfaceId);
}
