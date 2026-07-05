import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/menu_entity.dart';
import '../repository/menu_repository.dart';

class GetMenusUsecase {
  const GetMenusUsecase({required this.repository});

  final MenuRepository repository;

  Future<Either<Failure, List<MenuModule>>> call() => repository.getMenus();
}
