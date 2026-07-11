import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/privilege_datasource.dart';
import 'data/repository/privilege_repository_impl.dart';
import 'domain/repository/privilege_repository.dart';
import 'domain/usecase/privilege_delete.dart';
import 'domain/usecase/privilege_getlist.dart';
import 'domain/usecase/privilege_post.dart';
import 'domain/usecase/privilege_put.dart';
import 'presentation/bloc/privilege_bloc.dart';
import 'presentation/page/privilege_page.dart';

/// Módulo da interface 'privileges' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md, padrão weberpsetes). Montado como ModuleRoute
/// filho do Home; o título chega via arguments (nome da interface no menu),
/// com fallback pelo catálogo para refresh direto na URL.
class PrivilegesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<PrivilegeDatasource>(
            (i) => PrivilegeDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<PrivilegeRepository>(
            (i) => PrivilegeRepositoryImpl(datasource: i.get<PrivilegeDatasource>())),
        Bind.factory<PrivilegeGetlist>(
            (i) => PrivilegeGetlist(repository: i.get<PrivilegeRepository>())),
        Bind.factory<PrivilegePost>(
            (i) => PrivilegePost(repository: i.get<PrivilegeRepository>())),
        Bind.factory<PrivilegePut>(
            (i) => PrivilegePut(repository: i.get<PrivilegeRepository>())),
        Bind.factory<PrivilegeDelete>(
            (i) => PrivilegeDelete(repository: i.get<PrivilegeRepository>())),
        Bind.singleton<PrivilegeBloc>((i) => PrivilegeBloc(
              getlist: i.get<PrivilegeGetlist>(),
              post:    i.get<PrivilegePost>(),
              put:     i.get<PrivilegePut>(),
              delete:  i.get<PrivilegeDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => PrivilegePage(
              title: args.data as String? ??
                  trCatalog('privileges', 'Privileges', prefix: 'menu.interfaces'),
            )),
      ];
}
