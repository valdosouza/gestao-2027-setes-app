import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_salesman.dart';
import '../repository/salesman_repository.dart';

class SalesmanPut {
  const SalesmanPut({required this.repository});

  final SalesmanRepository repository;

  Future<Either<Failure, Unit>> call(ObjectSalesman salesman) =>
      repository.put(salesman);
}
