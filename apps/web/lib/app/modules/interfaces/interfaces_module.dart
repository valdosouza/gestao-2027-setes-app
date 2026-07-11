import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/interface_datasource.dart';
import 'data/repository/interface_repository_impl.dart';
import 'domain/repository/interface_repository.dart';
import 'domain/usecase/interface_delete.dart';
import 'domain/usecase/interface_getlist.dart';
import 'domain/usecase/interface_post.dart';
import 'domain/usecase/interface_put.dart';
import 'presentation/bloc/interface_bloc.dart';
import 'presentation/page/interface_page.dart';

/// Módulo da interface 'interfaces' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md, padrão weberpsetes). Montado como ModuleRoute
/// filho do Home; o título chega via arguments (nome da interface no menu),
/// com fallback pelo catálogo para refresh direto na URL.
class InterfacesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<InterfaceDatasource>(
            (i) => InterfaceDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<InterfaceRepository>(
            (i) => InterfaceRepositoryImpl(datasource: i.get<InterfaceDatasource>())),
        Bind.factory<InterfaceGetlist>(
            (i) => InterfaceGetlist(repository: i.get<InterfaceRepository>())),
        Bind.factory<InterfacePost>(
            (i) => InterfacePost(repository: i.get<InterfaceRepository>())),
        Bind.factory<InterfacePut>(
            (i) => InterfacePut(repository: i.get<InterfaceRepository>())),
        Bind.factory<InterfaceDelete>(
            (i) => InterfaceDelete(repository: i.get<InterfaceRepository>())),
        Bind.singleton<InterfaceBloc>((i) => InterfaceBloc(
              getlist: i.get<InterfaceGetlist>(),
              post:    i.get<InterfacePost>(),
              put:     i.get<InterfacePut>(),
              delete:  i.get<InterfaceDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => InterfacePage(
              title: args.data as String? ??
                  trCatalog('interfaces', 'Interfaces', prefix: 'menu.interfaces'),
            )),
      ];
}
