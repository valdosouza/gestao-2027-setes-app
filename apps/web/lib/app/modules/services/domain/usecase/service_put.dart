import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_entity.dart';
import '../repository/service_repository.dart';

class ServicePut {
  const ServicePut({required this.repository});

  final ServiceRepository repository;

  Future<Either<Failure, Unit>> call(int id, ServiceInput input) =>
      repository.put(id, input);
}
