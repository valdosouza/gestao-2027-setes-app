import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/service_order_repository.dart';

/// Abre OS manual para o cliente (trava D5 — 409 se já houver aberta).
class ServiceOrderPost {
  const ServiceOrderPost({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, int>> call(int customerId) =>
      repository.open(customerId);
}
