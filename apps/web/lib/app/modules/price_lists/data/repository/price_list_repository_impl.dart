import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/price_list_entity.dart';
import '../../domain/repository/price_list_repository.dart';
import '../datasource/price_list_datasource.dart';

class PriceListRepositoryImpl implements PriceListRepository {
  const PriceListRepositoryImpl({required this.datasource});

  final PriceListDatasource datasource;

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
  Future<Either<Failure, PagedResult<PriceListEntity>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, PriceListEntity>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(PriceListInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, PriceListInput input) =>
      _guard(() async {
        await datasource.put(id, input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
