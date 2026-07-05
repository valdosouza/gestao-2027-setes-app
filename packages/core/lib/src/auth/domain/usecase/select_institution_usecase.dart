import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../repository/auth_repository.dart';

class SelectInstitutionUsecase {
  const SelectInstitutionUsecase({required this.repository});

  final AuthRepository repository;

  /// Retorna o JWT final (POST /auth/select-institution).
  Future<Either<Failure, String>> call(String selectionToken, int institutionId) =>
      repository.selectInstitution(selectionToken, institutionId);
}
