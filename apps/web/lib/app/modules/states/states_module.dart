import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import 'data/datasource/state_datasource.dart';
import 'data/repository/state_repository_impl.dart';
import 'domain/repository/state_repository.dart';
import 'domain/usecase/state_delete.dart';
import 'domain/usecase/state_getlist.dart';
import 'domain/usecase/state_post.dart';
import 'domain/usecase/state_put.dart';
import 'presentation/bloc/state_bloc.dart';
import 'presentation/page/state_page.dart';

/// Módulo da interface 'states' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md, padrão weberpsetes). O lookup de País vem do
/// app/shared/lookup — módulo NUNCA importa módulo (regra de promoção).
class StatesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<StateDatasource>(
            (i) => StateDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<StateRepository>(
            (i) => StateRepositoryImpl(datasource: i.get<StateDatasource>())),
        Bind.factory<StateGetlist>(
            (i) => StateGetlist(repository: i.get<StateRepository>())),
        Bind.factory<StatePost>(
            (i) => StatePost(repository: i.get<StateRepository>())),
        Bind.factory<StatePut>(
            (i) => StatePut(repository: i.get<StateRepository>())),
        Bind.factory<StateDelete>(
            (i) => StateDelete(repository: i.get<StateRepository>())),
        Bind.singleton<StateBloc>((i) => StateBloc(
              getlist: i.get<StateGetlist>(),
              post:    i.get<StatePost>(),
              put:     i.get<StatePut>(),
              delete:  i.get<StateDelete>(),
            )),
        // Lookup de País (shared) — lista de apoio da FK tb_country_id
        Bind.lazySingleton<CountryLookupDatasource>(
            (i) => CountryLookupDatasourceImpl(client: i.get<ApiClient>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => StatePage(
              title: args.data as String? ??
                  trCatalog('states', 'States', prefix: 'menu.interfaces'),
            )),
      ];
}
