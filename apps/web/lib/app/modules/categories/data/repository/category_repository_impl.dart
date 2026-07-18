import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/category_entity.dart';
import '../../domain/repository/category_repository.dart';
import '../datasource/category_datasource.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl({required this.datasource});

  final CategoryDatasource datasource;

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
  Future<Either<Failure, List<CategoryEntity>>> getList(String kind) =>
      _guard(() => datasource.getList(kind));

  @override
  Future<Either<Failure, int>> post(CategoryEntity category) =>
      _guard(() => datasource.post(category));

  @override
  Future<Either<Failure, Unit>> put(CategoryEntity category) =>
      _guard(() async {
        await datasource.put(category);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
