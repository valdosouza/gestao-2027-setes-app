import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../cities/cities_module.dart';
import '../countries/countries_module.dart';
import '../states/states_module.dart';
import 'presentation/bloc/menu_bloc.dart';
import 'presentation/content/home_frames.dart';
import 'presentation/page/home_page.dart';

/// Shell pós-login. Cada interface do menu é um módulo independente
/// (ARQUITETURA_MODULOS.md, padrão weberpsetes): ModuleRoute filha da rota
/// '/', renderizada no RouterOutlet do conteúdo central. O clique no menu
/// faz Modular.to.navigate (interface_routes.dart) — binds de cada módulo
/// só vivem enquanto sua rota está ativa.
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
        ChildRoute(
          '/',
          child: (_, __) => const HomePage(),
          children: [
            // Conteúdo do RouterOutlet: 1 interface = 1 módulo
            ChildRoute('/welcome', child: (_, __) => const WelcomeFrame()),
            ChildRoute('/pending', child: (_, __) => const PendingInterfaceFrame()),
            ModuleRoute('/countries', module: CountriesModule()),
            ModuleRoute('/states',    module: StatesModule()),
            ModuleRoute('/cities',    module: CitiesModule()),
          ],
        ),
        // Personalização da identidade visual pelo cliente (decisões 16/27)
        ChildRoute('/theme', child: (_, __) => const ThemeSettingsPage()),
      ];
}
