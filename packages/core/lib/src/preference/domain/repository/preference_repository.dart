import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';

abstract class PreferenceRepository {
  Future<Either<Failure, Map<String, String>>> getAll();
  Future<Either<Failure, Unit>> save(String key, String value);
}
