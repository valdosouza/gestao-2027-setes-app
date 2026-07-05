import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
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
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }
}
