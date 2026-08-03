import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_carrier.dart';
import '../repository/carrier_repository.dart';

class CarrierPost {
  const CarrierPost({required this.repository});

  final CarrierRepository repository;

  Future<Either<Failure, CarrierPostResult>> call(ObjectCarrier carrier) =>
      repository.post(carrier);
}
