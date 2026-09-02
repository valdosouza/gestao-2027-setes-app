import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/price_list_entity.dart';
import '../repository/price_list_repository.dart';

/// Carrega a tabela de preço (GET /:id) para edição.
class PriceListGet {
  const PriceListGet({required this.repository});

  final PriceListRepository repository;

  Future<Either<Failure, PriceListEntity>> call(int id) =>
      repository.getById(id);
}
