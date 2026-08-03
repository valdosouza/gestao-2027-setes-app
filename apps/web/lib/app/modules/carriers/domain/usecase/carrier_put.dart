import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_carrier.dart';
import '../repository/carrier_repository.dart';

class CarrierPut {
  const CarrierPut({required this.repository});

  final CarrierRepository repository;

  Future<Either<Failure, Unit>> call(ObjectCarrier carrier) =>
      repository.put(carrier);
}
