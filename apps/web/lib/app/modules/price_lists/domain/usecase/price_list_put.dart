import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/price_list_entity.dart';
import '../repository/price_list_repository.dart';

class PriceListPut {
  const PriceListPut({required this.repository});

  final PriceListRepository repository;

  Future<Either<Failure, Unit>> call(int id, PriceListInput input) =>
      repository.put(id, input);
}
