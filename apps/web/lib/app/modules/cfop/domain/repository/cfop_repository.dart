import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/cfop_entity.dart';

/// Contrato do repositório de CFOP (Either/dartz).
abstract class CfopRepository {
  Future<Either<Failure, List<CfopEntity>>> getList(String filter);
  Future<Either<Failure, Unit>> post(CfopEntity cfop);
  Future<Either<Failure, Unit>> put(CfopEntity cfop);
  Future<Either<Failure, Unit>> delete(String id);
}
