import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_repository.dart';

class ServiceDelete {
  const ServiceDelete({required this.repository});

  final ServiceRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
