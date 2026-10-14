import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../../../shared/http/api_client.dart' show invalidResponseFailure;
import '../../domain/entity/institution_theme.dart';
import '../../domain/repository/theme_repository.dart';
import '../datasource/theme_remote_datasource.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  const ThemeRepositoryImpl({required this.datasource});

  final ThemeRemoteDatasource datasource;

  @override
  Future<Either<Failure, InstitutionTheme>> getTheme() async {
    try {
      return Right(await datasource.getTheme());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(invalidResponseFailure(e, service: 'setes-api'));   // D-F210: erro de LEITURA, nunca "rede" (a rede chega como Failure)
    }
  }

  @override
  Future<Either<Failure, Unit>> saveTheme(
      {String? primaryColor, String? secondaryColor, String? logoBase64}) async {
    try {
      await datasource.saveTheme(
          primaryColor: primaryColor, secondaryColor: secondaryColor, logoBase64: logoBase64);
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(invalidResponseFailure(e, service: 'setes-api'));   // D-F210: erro de LEITURA, nunca "rede" (a rede chega como Failure)
    }
  }
}
