import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_entity.dart';
import '../repository/category_repository.dart';

class CategoryPost {
  const CategoryPost({required this.repository});

  final CategoryRepository repository;

  Future<Either<Failure, int>> call(CategoryEntity category) =>
      repository.post(category);
}
