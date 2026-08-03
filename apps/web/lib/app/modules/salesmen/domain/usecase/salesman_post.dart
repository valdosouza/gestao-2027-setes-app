import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_salesman.dart';
import '../repository/salesman_repository.dart';

/// Promove o colaborador a vendedor (D1) — devolve o id do papel criado.
class SalesmanPost {
  const SalesmanPost({required this.repository});

  final SalesmanRepository repository;

  Future<Either<Failure, int>> call(ObjectSalesman salesman) =>
      repository.post(salesman);
}
