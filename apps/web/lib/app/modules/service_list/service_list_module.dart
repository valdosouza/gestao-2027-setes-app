import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/service_list_datasource.dart';
import 'data/repository/service_list_repository_impl.dart';
import 'domain/repository/service_list_repository.dart';
import 'domain/usecase/service_list_delete.dart';
import 'domain/usecase/service_list_getlist.dart';
import 'domain/usecase/service_list_post.dart';
import 'domain/usecase/service_list_put.dart';
import 'presentation/bloc/service_list_bloc.dart';
import 'presentation/page/service_list_page.dart';

/// Módulo da interface 'service-list' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Lista de Serviços da LC 116 — referência
/// fiscal do catálogo central, módulo SUPER (guard isSuper() no backend;
/// D10 da regra de tributação de serviço).
class ServiceListModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ServiceListDatasource>(
            (i) => ServiceListDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceListRepository>((i) =>
            ServiceListRepositoryImpl(
                datasource: i.get<ServiceListDatasource>())),
        Bind.factory<ServiceListGetlist>((i) =>
            ServiceListGetlist(repository: i.get<ServiceListRepository>())),
        Bind.factory<ServiceListPost>((i) =>
            ServiceListPost(repository: i.get<ServiceListRepository>())),
        Bind.factory<ServiceListPut>((i) =>
            ServiceListPut(repository: i.get<ServiceListRepository>())),
        Bind.factory<ServiceListDelete>((i) =>
            ServiceListDelete(repository: i.get<ServiceListRepository>())),
        Bind.singleton<ServiceListBloc>((i) => ServiceListBloc(
              getlist: i.get<ServiceListGetlist>(),
              post:    i.get<ServiceListPost>(),
              put:     i.get<ServiceListPut>(),
              delete:  i.get<ServiceListDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => ServiceListPage(
              title: args.data as String? ??
                  trCatalog('service-list', 'Lista de Serviços',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
