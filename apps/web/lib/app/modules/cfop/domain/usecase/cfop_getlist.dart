import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cfop_entity.dart';
import '../repository/cfop_repository.dart';

class CfopGetlist {
  const CfopGetlist({required this.repository});

  final CfopRepository repository;

  Future<Either<Failure, List<CfopEntity>>> call(String filter) =>
      repository.getList(filter);
}
