import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/module_datasource.dart';
import 'data/repository/module_repository_impl.dart';
import 'domain/repository/module_repository.dart';
import 'domain/usecase/module_delete.dart';
import 'domain/usecase/module_getlist.dart';
import 'domain/usecase/module_interface_options.dart';
import 'domain/usecase/module_post.dart';
import 'domain/usecase/module_put.dart';
import 'presentation/bloc/module_bloc.dart';
import 'presentation/page/module_page.dart';

/// Módulo da interface 'modules' — Módulos de Menu do cliente, camada 2 do
/// menu (prompt_modulo_menus.md D1–D4; 1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Montado como ModuleRoute filho do Home; o
/// título chega via arguments (nome da interface no menu), com fallback
/// pelo catálogo para refresh direto na URL.
class ModulesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ModuleDatasource>(
            (i) => ModuleDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ModuleRepository>(
            (i) => ModuleRepositoryImpl(datasource: i.get<ModuleDatasource>())),
        Bind.factory<ModuleGetlist>(
            (i) => ModuleGetlist(repository: i.get<ModuleRepository>())),
        Bind.factory<ModuleInterfaceOptions>(
            (i) => ModuleInterfaceOptions(repository: i.get<ModuleRepository>())),
        Bind.factory<ModulePost>(
            (i) => ModulePost(repository: i.get<ModuleRepository>())),
        Bind.factory<ModulePut>(
            (i) => ModulePut(repository: i.get<ModuleRepository>())),
        Bind.factory<ModuleDelete>(
            (i) => ModuleDelete(repository: i.get<ModuleRepository>())),
        Bind.singleton<ModuleBloc>((i) => ModuleBloc(
              getlist:          i.get<ModuleGetlist>(),
              interfaceOptions: i.get<ModuleInterfaceOptions>(),
              post:             i.get<ModulePost>(),
              put:              i.get<ModulePut>(),
              delete:           i.get<ModuleDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => ModulePage(
              title: args.data as String? ??
                  trCatalog('modules', 'Menu Modules', prefix: 'menu.interfaces'),
            )),
      ];
}
