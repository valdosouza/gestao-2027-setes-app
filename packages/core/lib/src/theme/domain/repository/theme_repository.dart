import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/institution_theme.dart';

abstract class ThemeRepository {
  Future<Either<Failure, InstitutionTheme>> getTheme();
  Future<Either<Failure, Unit>> saveTheme({String? primaryColor, String? secondaryColor, String? logoBase64});
}
