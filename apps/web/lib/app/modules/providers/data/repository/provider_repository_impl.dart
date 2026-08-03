import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_provider.dart';
import '../../domain/repository/provider_repository.dart';
import '../datasource/provider_datasource.dart';

class ProviderRepositoryImpl implements ProviderRepository {
  const ProviderRepositoryImpl({required this.datasource});

  final ProviderDatasource datasource;

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
  Future<Either<Failure, PagedResult<ProviderListItem>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, ObjectProvider>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, ProviderPostResult>> post(ObjectProvider provider) =>
      _guard(() => datasource.post(provider));

  @override
  Future<Either<Failure, Unit>> put(ObjectProvider provider) =>
      _guard(() async {
        await datasource.put(provider);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
