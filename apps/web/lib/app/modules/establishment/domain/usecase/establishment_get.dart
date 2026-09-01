import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_establishment.dart';
import '../repository/establishment_repository.dart';

class EstablishmentGet {
  const EstablishmentGet({required this.repository});

  final EstablishmentRepository repository;

  Future<Either<Failure, ObjectEstablishment>> call() => repository.get();
}
