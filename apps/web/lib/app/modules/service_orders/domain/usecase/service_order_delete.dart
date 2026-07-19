import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_repository.dart';

/// Cancela a OS ABERTA (soft delete — libera a trava D5; 409 se faturada).
class ServiceOrderDelete {
  const ServiceOrderDelete({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.cancel(id);
}
