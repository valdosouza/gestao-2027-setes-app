import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_salesman.dart';
import '../repository/salesman_repository.dart';

class SalesmanGet {
  const SalesmanGet({required this.repository});

  final SalesmanRepository repository;

  Future<Either<Failure, ObjectSalesman>> call(int id) => repository.get(id);
}
