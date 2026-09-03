import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_list_entity.dart';
import '../repository/service_list_repository.dart';

class ServiceListPut {
  const ServiceListPut({required this.repository});

  final ServiceListRepository repository;

  Future<Either<Failure, Unit>> call(ServiceListEntity item) =>
      repository.put(item);
}
