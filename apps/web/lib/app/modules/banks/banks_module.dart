import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/bank_datasource.dart';
import 'data/repository/bank_repository_impl.dart';
import 'domain/repository/bank_repository.dart';
import 'domain/usecase/bank_delete.dart';
import 'domain/usecase/bank_getlist.dart';
import 'domain/usecase/bank_post.dart';
import 'domain/usecase/bank_put.dart';
import 'presentation/bloc/bank_bloc.dart';
import 'presentation/page/bank_page.dart';

/// Módulo da interface 'banks' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md, padrão weberpsetes). Montado como ModuleRoute
/// filho do Home; o título chega via arguments (nome da interface no menu),
/// com fallback pelo catálogo para refresh direto na URL.
class BanksModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<BankDatasource>(
            (i) => BankDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<BankRepository>(
            (i) => BankRepositoryImpl(datasource: i.get<BankDatasource>())),
        Bind.factory<BankGetlist>(
            (i) => BankGetlist(repository: i.get<BankRepository>())),
        Bind.factory<BankPost>(
            (i) => BankPost(repository: i.get<BankRepository>())),
        Bind.factory<BankPut>(
            (i) => BankPut(repository: i.get<BankRepository>())),
        Bind.factory<BankDelete>(
            (i) => BankDelete(repository: i.get<BankRepository>())),
        Bind.singleton<BankBloc>((i) => BankBloc(
              getlist: i.get<BankGetlist>(),
              post:    i.get<BankPost>(),
              put:     i.get<BankPut>(),
              delete:  i.get<BankDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => BankPage(
              title: args.data as String? ??
                  trCatalog('banks', 'Banks', prefix: 'menu.interfaces'),
            )),
      ];
}
