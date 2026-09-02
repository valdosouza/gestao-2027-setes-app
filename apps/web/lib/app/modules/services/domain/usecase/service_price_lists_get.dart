import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_entity.dart';
import '../repository/service_repository.dart';

/// Grade vazia do serviço NOVO: as tabelas de preço vivas da institution
/// (priceTag null em todas — D4/D7).
class ServicePriceListsGet {
  const ServicePriceListsGet({required this.repository});

  final ServiceRepository repository;

  Future<Either<Failure, List<ServicePrice>>> call() =>
      repository.priceLists();
}
