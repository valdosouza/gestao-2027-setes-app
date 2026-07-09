import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/home/home_module.dart';

/// Módulo raiz (decisão 12: flutter_modular v5 para rotas e DI).
/// Auth vem PRONTO do packages/core (decisão 25 — modelo GestaoERPApps):
/// o app só fornece ApiClient/LocalPrefs e a rota /home.
class AppModule extends Module {
  @override
  List<Bind> get binds => [
        // Singleton: uma sessão HTTP/JWT para o app inteiro
        Bind.singleton<ApiClient>((_) => ApiClient()),
        Bind.singleton<LocalPrefs>((_) => LocalPrefs()),
        // Preferências do usuário (decisão 14) — usadas em qualquer módulo pós-login
        Bind.lazySingleton<PreferenceRemoteDatasource>(
            (i) => PreferenceRemoteDatasource(client: i.get<ApiClient>())),
        Bind.lazySingleton<PreferenceRepository>(
            (i) => PreferenceRepositoryImpl(datasource: i.get<PreferenceRemoteDatasource>())),
        Bind.factory<GetPreferencesUsecase>(
            (i) => GetPreferencesUsecase(repository: i.get<PreferenceRepository>())),
        Bind.factory<SavePreferenceUsecase>(
            (i) => SavePreferenceUsecase(repository: i.get<PreferenceRepository>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ModuleRoute('/', module: AuthModule()),
        ModuleRoute('/home', module: HomeModule()),
      ];
}
