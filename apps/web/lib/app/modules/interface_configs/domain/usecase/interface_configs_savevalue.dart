import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/interface_configs_repository.dart';

class InterfaceConfigsSavevalue {
  const InterfaceConfigsSavevalue({required this.repository});

  final InterfaceConfigsRepository repository;

  Future<Either<Failure, Unit>> call({
    required int interfaceId,
    required String name,
    required String? content,
    required bool asUser,
  }) =>
      repository.saveValue(
        interfaceId: interfaceId,
        name: name,
        content: content,
        asUser: asUser,
      );
}
