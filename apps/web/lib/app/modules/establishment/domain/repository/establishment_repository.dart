import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_establishment.dart';

abstract class EstablishmentRepository {
  Future<Either<Failure, ObjectEstablishment>> get();
  Future<Either<Failure, ObjectEstablishment>> put(
      ObjectEstablishment establishment);
}
