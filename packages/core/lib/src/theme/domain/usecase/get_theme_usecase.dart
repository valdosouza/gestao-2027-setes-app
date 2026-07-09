import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/institution_theme.dart';
import '../repository/theme_repository.dart';

class GetThemeUsecase {
  const GetThemeUsecase({required this.repository});

  final ThemeRepository repository;

  Future<Either<Failure, InstitutionTheme>> call() => repository.getTheme();
}
