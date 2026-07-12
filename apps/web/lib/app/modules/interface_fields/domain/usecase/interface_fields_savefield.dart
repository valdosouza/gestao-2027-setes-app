import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/interface_fields_repository.dart';

class InterfaceFieldsSavefield {
  const InterfaceFieldsSavefield({required this.repository});

  final InterfaceFieldsRepository repository;

  Future<Either<Failure, Unit>> call({
    required int interfaceId,
    required String fieldName,
    String? caption,
    bool required = false,
    String? mask,
  }) =>
      repository.saveField(
        interfaceId: interfaceId,
        fieldName: fieldName,
        caption: caption,
        required: required,
        mask: mask,
      );
}
