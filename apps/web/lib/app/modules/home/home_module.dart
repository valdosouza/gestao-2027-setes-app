import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/bloc/menu_bloc.dart';
import 'presentation/page/home_page.dart';

class HomeModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<MenuRemoteDatasource>(
            (i) => MenuRemoteDatasource(client: i.get<ApiClient>())),
        Bind.lazySingleton<MenuRepository>(
            (i) => MenuRepositoryImpl(datasource: i.get<MenuRemoteDatasource>())),
        Bind.factory<GetMenusUsecase>(
            (i) => GetMenusUsecase(repository: i.get<MenuRepository>())),
        Bind.singleton<MenuBloc>((i) => MenuBloc(usecase: i.get<GetMenusUsecase>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, __) => const HomePage()),
      ];
}
