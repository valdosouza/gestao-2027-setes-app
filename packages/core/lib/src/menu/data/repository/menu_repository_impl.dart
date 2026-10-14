import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../../../shared/http/api_client.dart' show invalidResponseFailure;
import '../../domain/entity/menu_entity.dart';
import '../../domain/repository/menu_repository.dart';
import '../datasource/menu_remote_datasource.dart';

class MenuRepositoryImpl implements MenuRepository {
  const MenuRepositoryImpl({required this.datasource});

  final MenuRemoteDatasource datasource;

  @override
  Future<Either<Failure, List<MenuModule>>> getMenus() async {
    try {
      return Right(await datasource.getMenus());
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(invalidResponseFailure(e));   // D-F210: erro de LEITURA, nunca "rede" (a rede chega como Failure)
    }
  }
}
