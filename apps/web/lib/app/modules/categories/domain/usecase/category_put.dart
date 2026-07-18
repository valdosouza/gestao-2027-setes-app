import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_entity.dart';
import '../repository/category_repository.dart';

class CategoryPut {
  const CategoryPut({required this.repository});

  final CategoryRepository repository;

  Future<Either<Failure, Unit>> call(CategoryEntity category) =>
      repository.put(category);
}
