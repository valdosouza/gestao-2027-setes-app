import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/institution_repository.dart';

class InstitutionDelete {
  const InstitutionDelete({required this.repository});

  final InstitutionRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
