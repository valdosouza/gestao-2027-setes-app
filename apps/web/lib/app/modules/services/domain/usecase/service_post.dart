import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_entity.dart';
import '../repository/service_repository.dart';

class ServicePost {
  const ServicePost({required this.repository});

  final ServiceRepository repository;

  Future<Either<Failure, int>> call(ServiceInput input) =>
      repository.post(input);
}
