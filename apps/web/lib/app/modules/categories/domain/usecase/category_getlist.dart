import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_entity.dart';
import '../repository/category_repository.dart';

class CategoryGetlist {
  const CategoryGetlist({required this.repository});

  final CategoryRepository repository;

  Future<Either<Failure, List<CategoryEntity>>> call(String kind) =>
      repository.getList(kind);
}
