import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_institution.dart';
import '../repository/institution_repository.dart';

class InstitutionGetlist {
  const InstitutionGetlist({required this.repository});

  final InstitutionRepository repository;

  Future<Either<Failure, List<InstitutionListItem>>> call(String filter) =>
      repository.getList(filter);
}
