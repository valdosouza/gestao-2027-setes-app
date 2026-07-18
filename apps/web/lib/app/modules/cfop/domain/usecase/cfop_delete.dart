import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/cfop_repository.dart';

class CfopDelete {
  const CfopDelete({required this.repository});

  final CfopRepository repository;

  Future<Either<Failure, Unit>> call(String id) => repository.delete(id);
}
