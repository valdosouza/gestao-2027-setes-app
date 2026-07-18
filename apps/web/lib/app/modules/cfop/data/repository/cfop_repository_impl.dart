import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/cfop_entity.dart';
import '../../domain/repository/cfop_repository.dart';
import '../datasource/cfop_datasource.dart';

class CfopRepositoryImpl implements CfopRepository {
  const CfopRepositoryImpl({required this.datasource});

  final CfopDatasource datasource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      return Left(Failure(message: err.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CfopEntity>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, Unit>> post(CfopEntity cfop) => _guard(() async {
        await datasource.post(cfop);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> put(CfopEntity cfop) => _guard(() async {
        await datasource.put(cfop);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(String id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
