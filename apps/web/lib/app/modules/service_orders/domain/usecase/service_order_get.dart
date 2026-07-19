import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// Carrega a OS completa (itens + totalizer + fatura) para o detalhe.
class ServiceOrderGet {
  const ServiceOrderGet({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, ServiceOrderFull>> call(int id) =>
      repository.getById(id);
}
