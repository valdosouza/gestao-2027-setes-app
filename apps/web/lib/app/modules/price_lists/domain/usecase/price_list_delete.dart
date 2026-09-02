import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/price_list_repository.dart';

class PriceListDelete {
  const PriceListDelete({required this.repository});

  final PriceListRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
