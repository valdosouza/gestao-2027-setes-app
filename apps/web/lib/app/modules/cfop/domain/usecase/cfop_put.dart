import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cfop_entity.dart';
import '../repository/cfop_repository.dart';

class CfopPut {
  const CfopPut({required this.repository});

  final CfopRepository repository;

  Future<Either<Failure, Unit>> call(CfopEntity cfop) => repository.put(cfop);
}
