import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_list_repository.dart';

class ServiceListDelete {
  const ServiceListDelete({required this.repository});

  final ServiceListRepository repository;

  Future<Either<Failure, Unit>> call(String id) => repository.delete(id);
}
