import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/price_list_entity.dart';
import '../repository/price_list_repository.dart';

class PriceListPost {
  const PriceListPost({required this.repository});

  final PriceListRepository repository;

  Future<Either<Failure, int>> call(PriceListInput input) =>
      repository.post(input);
}
