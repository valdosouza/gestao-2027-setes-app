import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_carrier.dart';
import '../repository/carrier_repository.dart';

class CarrierGet {
  const CarrierGet({required this.repository});

  final CarrierRepository repository;

  Future<Either<Failure, ObjectCarrier>> call(int id) => repository.get(id);
}
