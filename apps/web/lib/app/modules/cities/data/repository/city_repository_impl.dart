import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/city_entity.dart';
import '../../domain/repository/city_repository.dart';
import '../datasource/city_datasource.dart';

class CityRepositoryImpl implements CityRepository {
  const CityRepositoryImpl({required this.datasource});

  final CityDatasource datasource;

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
  Future<Either<Failure, List<CityEntity>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, int>> post(CityEntity city) =>
      _guard(() => datasource.post(city));

  @override
  Future<Either<Failure, Unit>> put(CityEntity city) => _guard(() async {
        await datasource.put(city);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
