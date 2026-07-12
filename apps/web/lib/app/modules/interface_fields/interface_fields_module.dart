import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/interface_fields_datasource.dart';
import 'data/repository/interface_fields_repository_impl.dart';
import 'domain/repository/interface_fields_repository.dart';
import 'domain/usecase/interface_fields_getfields.dart';
import 'domain/usecase/interface_fields_getvitrine.dart';
import 'domain/usecase/interface_fields_savefield.dart';
import 'presentation/bloc/interface_fields_bloc.dart';
import 'presentation/page/interface_fields_page.dart';

/// Módulo da interface 'interface-fields' — painel Sistema/Admin de campos
/// configuráveis (decisões 6 e 9 da Fase 2; 1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Módulo do CLIENTE: acesso controlado pelo
/// contrato comercial + privilégio da tela (sem super).
class InterfaceFieldsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<InterfaceFieldsDatasource>(
            (i) => InterfaceFieldsDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<InterfaceFieldsRepository>((i) =>
            InterfaceFieldsRepositoryImpl(
                datasource: i.get<InterfaceFieldsDatasource>())),
        Bind.factory<InterfaceFieldsGetvitrine>((i) =>
            InterfaceFieldsGetvitrine(
                repository: i.get<InterfaceFieldsRepository>())),
        Bind.factory<InterfaceFieldsGetfields>((i) =>
            InterfaceFieldsGetfields(
                repository: i.get<InterfaceFieldsRepository>())),
        Bind.factory<InterfaceFieldsSavefield>((i) =>
            InterfaceFieldsSavefield(
                repository: i.get<InterfaceFieldsRepository>())),
        Bind.singleton<InterfaceFieldsBloc>((i) => InterfaceFieldsBloc(
              getVitrine: i.get<InterfaceFieldsGetvitrine>(),
              getFields:  i.get<InterfaceFieldsGetfields>(),
              saveField:  i.get<InterfaceFieldsSavefield>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => InterfaceFieldsPage(
              title: args.data as String? ??
                  trCatalog('interface-fields', 'Interface Fields',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
