import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/carrier_repository.dart';

class CarrierDelete {
  const CarrierDelete({required this.repository});

  final CarrierRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
