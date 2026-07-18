import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../repository/interface_fields_repository.dart';

class InterfaceFieldsGetvitrine {
  const InterfaceFieldsGetvitrine({required this.repository});

  final InterfaceFieldsRepository repository;

  Future<Either<Failure, List<InterfaceVitrineEntity>>> call(String filter) =>
      repository.vitrine(filter);
}
