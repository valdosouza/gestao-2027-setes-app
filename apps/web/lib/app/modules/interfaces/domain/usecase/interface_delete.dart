import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/interface_repository.dart';

class InterfaceDelete {
  const InterfaceDelete({required this.repository});

  final InterfaceRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
