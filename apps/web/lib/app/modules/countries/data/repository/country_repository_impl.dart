import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/country_entity.dart';
import '../../domain/repository/country_repository.dart';
import '../datasource/country_datasource.dart';

class CountryRepositoryImpl implements CountryRepository {
  const CountryRepositoryImpl({required this.datasource});

  final CountryDatasource datasource;

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
  Future<Either<Failure, List<CountryEntity>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, int>> post(CountryEntity country) =>
      _guard(() => datasource.post(country));

  @override
  Future<Either<Failure, Unit>> put(CountryEntity country) =>
      _guard(() async {
        await datasource.put(country);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
