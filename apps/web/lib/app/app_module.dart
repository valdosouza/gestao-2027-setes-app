import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/home/home_module.dart';
import 'shared/field_config/datasource/field_config_datasource.dart';
import 'shared/interface_config/datasource/interface_config_datasource.dart';
import 'shared/session/session_context.dart';
import 'shared/users/datasource/user_datasource.dart';

/// Módulo raiz (decisão 12: flutter_modular v5 para rotas e DI).
/// Auth vem PRONTO do packages/core (decisão 25 — modelo GestaoERPApps):
/// o app só fornece ApiClient/LocalPrefs e a rota /home.
class AppModule extends Module {
  @override
  List<Bind> get binds => [
        // D-F138 (F2b): UM token do produto (ProductToken) para as N APIs —
        // cada API tem o seu cliente (base de URL própria), todos leem o
        // token daqui a cada requisição; 401 com token = sessão morta (o
        // AppWidget volta ao login — uma vez, para todas as APIs)
        Bind.singleton<ProductToken>((_) => ProductToken()),
        Bind.singleton<ApiClient>((i) => ApiClient(session: i.get<ProductToken>())),
        // D-F4: a nfse-api (NFS-e) é falada DIRETO pelo app — datasource
        // da nfse-api pede NfseApiClient, nunca o ApiClient do setes-api
        Bind.singleton<NfseApiClient>(
            (i) => NfseApiClient(session: i.get<ProductToken>())),
        Bind.singleton<LocalPrefs>((_) => LocalPrefs()),
        // Engine de campos configuráveis (Fase 2, decisão 7): toda tela de
        // cadastro consulta a config resolvida na montagem — bind global.
        Bind.lazySingleton<FieldConfigDatasource>(
            (i) => FieldConfigDatasourceImpl(client: i.get<ApiClient>())),
        // Engine de CONFIGURAÇÕES do sistema (Framework de Configurações,
        // decisão 4): config resolvida usuário → institution → default.
        Bind.lazySingleton<InterfaceConfigDatasource>(
            (i) => InterfaceConfigDatasourceImpl(client: i.get<ApiClient>())),
        // SessionContext único (decisão 17 — fim das GB_* do Delphi):
        // preenchido na entrada da Home, somente leitura para as telas.
        Bind.singleton<SessionContext>((_) => SessionContext()),
        // Usuários (workflow 2026-07-12): compartilhado entre o módulo users
        // e a aba Usuários do Estabelecimento — bind global.
        Bind.lazySingleton<UserDatasource>(
            (i) => UserDatasourceImpl(client: i.get<ApiClient>())),
        // UserBadge (home): identificação do usuário logado via /api/core/me.
        // Binds próprios no root — os do AuthModule são descartados ao sair de '/'.
        Bind.factory<GetMeUsecase>((i) => GetMeUsecase(
              repository: AuthRepositoryImpl(
                datasource: AuthRemoteDatasource(client: i.get<ApiClient>()),
              ),
            )),
        // Preferências do usuário (decisão 14) — usadas em qualquer módulo pós-login
        Bind.lazySingleton<PreferenceRemoteDatasource>(
            (i) => PreferenceRemoteDatasource(client: i.get<ApiClient>())),
        Bind.lazySingleton<PreferenceRepository>(
            (i) => PreferenceRepositoryImpl(datasource: i.get<PreferenceRemoteDatasource>())),
        Bind.factory<GetPreferencesUsecase>(
            (i) => GetPreferencesUsecase(repository: i.get<PreferenceRepository>())),
        Bind.factory<SavePreferenceUsecase>(
            (i) => SavePreferenceUsecase(repository: i.get<PreferenceRepository>())),
        // Tema por institution (decisões 16 e 27) — aplicado no MaterialApp
        Bind.lazySingleton<ThemeRemoteDatasource>(
            (i) => ThemeRemoteDatasource(client: i.get<ApiClient>())),
        Bind.lazySingleton<ThemeRepository>(
            (i) => ThemeRepositoryImpl(datasource: i.get<ThemeRemoteDatasource>())),
        Bind.factory<GetThemeUsecase>(
            (i) => GetThemeUsecase(repository: i.get<ThemeRepository>())),
        Bind.factory<SaveThemeUsecase>(
            (i) => SaveThemeUsecase(repository: i.get<ThemeRepository>())),
        Bind.singleton<ThemeCubit>((i) => ThemeCubit(
              getUsecase: i.get<GetThemeUsecase>(),
              saveUsecase: i.get<SaveThemeUsecase>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ModuleRoute('/', module: AuthModule()),
        // Guard: restaura a sessão persistida no refresh; sem sessão → /login
        ModuleRoute('/home', module: HomeModule(), guards: [SetesAuthGuard()]),
      ];
}
