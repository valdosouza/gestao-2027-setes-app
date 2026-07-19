import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// Lista as OS da institution por [status] 'A'|'F' e filtro de cliente.
class ServiceOrderGetlist {
  const ServiceOrderGetlist({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, List<ServiceOrderListItem>>> call(
          String status, String filter) =>
      repository.getList(status, filter);
}
