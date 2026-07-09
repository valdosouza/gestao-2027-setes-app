import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../repository/theme_repository.dart';

class SaveThemeUsecase {
  const SaveThemeUsecase({required this.repository});

  final ThemeRepository repository;

  Future<Either<Failure, Unit>> call(
          {String? primaryColor, String? secondaryColor, String? logoBase64}) =>
      repository.saveTheme(
          primaryColor: primaryColor, secondaryColor: secondaryColor, logoBase64: logoBase64);
}
