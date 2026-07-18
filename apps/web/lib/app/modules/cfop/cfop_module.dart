import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/cfop_datasource.dart';
import 'data/repository/cfop_repository_impl.dart';
import 'domain/repository/cfop_repository.dart';
import 'domain/usecase/cfop_delete.dart';
import 'domain/usecase/cfop_getlist.dart';
import 'domain/usecase/cfop_post.dart';
import 'domain/usecase/cfop_put.dart';
import 'presentation/bloc/cfop_bloc.dart';
import 'presentation/page/cfop_page.dart';

/// Módulo da interface 'cfop' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Referência fiscal do catálogo central —
/// módulo SUPER (guard isSuper() no backend).
class CfopModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CfopDatasource>(
            (i) => CfopDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CfopRepository>(
            (i) => CfopRepositoryImpl(datasource: i.get<CfopDatasource>())),
        Bind.factory<CfopGetlist>(
            (i) => CfopGetlist(repository: i.get<CfopRepository>())),
        Bind.factory<CfopPost>(
            (i) => CfopPost(repository: i.get<CfopRepository>())),
        Bind.factory<CfopPut>(
            (i) => CfopPut(repository: i.get<CfopRepository>())),
        Bind.factory<CfopDelete>(
            (i) => CfopDelete(repository: i.get<CfopRepository>())),
        Bind.singleton<CfopBloc>((i) => CfopBloc(
              getlist: i.get<CfopGetlist>(),
              post:    i.get<CfopPost>(),
              put:     i.get<CfopPut>(),
              delete:  i.get<CfopDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CfopPage(
              title: args.data as String? ??
                  trCatalog('cfop', 'CFOP', prefix: 'menu.interfaces'),
            )),
      ];
}
