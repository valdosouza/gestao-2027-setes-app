import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_establishment.dart';
import '../repository/establishment_repository.dart';

class EstablishmentPut {
  const EstablishmentPut({required this.repository});

  final EstablishmentRepository repository;

  Future<Either<Failure, ObjectEstablishment>> call(
          ObjectEstablishment establishment) =>
      repository.put(establishment);
}
