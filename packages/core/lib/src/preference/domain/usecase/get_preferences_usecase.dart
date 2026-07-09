import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../repository/preference_repository.dart';

class GetPreferencesUsecase {
  const GetPreferencesUsecase({required this.repository});

  final PreferenceRepository repository;

  Future<Either<Failure, Map<String, String>>> call() => repository.getAll();
}
