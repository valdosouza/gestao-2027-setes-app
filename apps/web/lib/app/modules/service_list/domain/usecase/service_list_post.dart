import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_list_entity.dart';
import '../repository/service_list_repository.dart';

class ServiceListPost {
  const ServiceListPost({required this.repository});

  final ServiceListRepository repository;

  Future<Either<Failure, Unit>> call(ServiceListEntity item) =>
      repository.post(item);
}
