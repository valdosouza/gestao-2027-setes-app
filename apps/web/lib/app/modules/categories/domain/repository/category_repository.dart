import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_entity.dart';

/// Contrato do repositório de Categoria (Either/dartz).
abstract class CategoryRepository {
  Future<Either<Failure, List<CategoryEntity>>> getList(String kind);
  Future<Either<Failure, int>> post(CategoryEntity category);
  Future<Either<Failure, Unit>> put(CategoryEntity category);
  Future<Either<Failure, Unit>> delete(int id);
}
