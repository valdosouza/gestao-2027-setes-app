import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../repository/preference_repository.dart';

class SavePreferenceUsecase {
  const SavePreferenceUsecase({required this.repository});

  final PreferenceRepository repository;

  Future<Either<Failure, Unit>> call(String key, String value) =>
      repository.save(key, value);
}
