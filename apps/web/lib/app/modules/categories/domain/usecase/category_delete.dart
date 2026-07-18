import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/category_repository.dart';

class CategoryDelete {
  const CategoryDelete({required this.repository});

  final CategoryRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
