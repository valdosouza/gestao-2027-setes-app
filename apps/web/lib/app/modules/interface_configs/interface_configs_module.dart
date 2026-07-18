import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/interface_configs_datasource.dart';
import 'data/repository/interface_configs_repository_impl.dart';
import 'domain/repository/interface_configs_repository.dart';
import 'domain/usecase/interface_configs_getconfigs.dart';
import 'domain/usecase/interface_configs_getvitrine.dart';
import 'domain/usecase/interface_configs_savevalue.dart';
import 'presentation/bloc/interface_configs_bloc.dart';
import 'presentation/page/interface_configs_page.dart';

/// Módulo da interface 'interface-configs' — painel de configurações do
/// sistema (Framework de Configurações, decisões 7 e 9; 1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Módulo do CLIENTE, grupo Sistema.
///
/// A rota aceita como argumento o título (String, navegação pelo menu) OU
/// um Map {'title', 'moduleKey'} — atalho da engrenagem na tela de LISTA
/// (decisão 11): abre o painel já filtrado na interface do módulo.
class InterfaceConfigsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<InterfaceConfigsDatasource>(
            (i) => InterfaceConfigsDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<InterfaceConfigsRepository>((i) =>
            InterfaceConfigsRepositoryImpl(
                datasource: i.get<InterfaceConfigsDatasource>())),
        Bind.factory<InterfaceConfigsGetvitrine>((i) =>
            InterfaceConfigsGetvitrine(
                repository: i.get<InterfaceConfigsRepository>())),
        Bind.factory<InterfaceConfigsGetconfigs>((i) =>
            InterfaceConfigsGetconfigs(
                repository: i.get<InterfaceConfigsRepository>())),
        Bind.factory<InterfaceConfigsSavevalue>((i) =>
            InterfaceConfigsSavevalue(
                repository: i.get<InterfaceConfigsRepository>())),
        Bind.singleton<InterfaceConfigsBloc>((i) => InterfaceConfigsBloc(
              getVitrine: i.get<InterfaceConfigsGetvitrine>(),
              getConfigs: i.get<InterfaceConfigsGetconfigs>(),
              saveValue:  i.get<InterfaceConfigsSavevalue>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) {
          final data = args.data;
          final fallbackTitle = trCatalog(
              'interface-configs', 'Interface Configs',
              prefix: 'menu.interfaces');
          if (data is Map) {
            return InterfaceConfigsPage(
              title: data['title'] as String? ?? fallbackTitle,
              initialModuleKey: data['moduleKey'] as String?,
              returnRoute: data['returnTo'] as String?,
            );
          }
          return InterfaceConfigsPage(
              title: data as String? ?? fallbackTitle);
        }),
      ];
}
