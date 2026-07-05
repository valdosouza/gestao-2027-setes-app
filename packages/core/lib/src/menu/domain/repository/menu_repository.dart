import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/menu_entity.dart';

abstract class MenuRepository {
  Future<Either<Failure, List<MenuModule>>> getMenus();
}
