import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/salesman_datasource.dart';
import 'data/repository/salesman_repository_impl.dart';
import 'domain/repository/salesman_repository.dart';
import 'domain/usecase/salesman_delete.dart';
import 'domain/usecase/salesman_get.dart';
import 'domain/usecase/salesman_getlist.dart';
import 'domain/usecase/salesman_post.dart';
import 'domain/usecase/salesman_put.dart';
import 'presentation/bloc/salesman_bloc.dart';
import 'presentation/page/salesman_page.dart';

/// Módulo da interface 'salesmen' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Onda 2 da Entidade Única (D1/D5): vendedor é
/// PROMOÇÃO de colaborador — sem cadeia fiscal, sem abas compartilhadas; o
/// lookup de colaboradores vive no próprio datasource (só este módulo usa —
/// regra de promoção).
class SalesmenModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<SalesmanDatasource>(
            (i) => SalesmanDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<SalesmanRepository>((i) =>
            SalesmanRepositoryImpl(datasource: i.get<SalesmanDatasource>())),
        Bind.factory<SalesmanGetlist>(
            (i) => SalesmanGetlist(repository: i.get<SalesmanRepository>())),
        Bind.factory<SalesmanGet>(
            (i) => SalesmanGet(repository: i.get<SalesmanRepository>())),
        Bind.factory<SalesmanPost>(
            (i) => SalesmanPost(repository: i.get<SalesmanRepository>())),
        Bind.factory<SalesmanPut>(
            (i) => SalesmanPut(repository: i.get<SalesmanRepository>())),
        Bind.factory<SalesmanDelete>(
            (i) => SalesmanDelete(repository: i.get<SalesmanRepository>())),
        Bind.singleton<SalesmanBloc>((i) => SalesmanBloc(
              getlist: i.get<SalesmanGetlist>(),
              get:     i.get<SalesmanGet>(),
              post:    i.get<SalesmanPost>(),
              put:     i.get<SalesmanPut>(),
              delete:  i.get<SalesmanDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => SalesmanPage(
              title: args.data as String? ??
                  trCatalog('salesmen', 'Salesmen',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
