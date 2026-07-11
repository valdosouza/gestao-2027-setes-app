import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/country_datasource.dart';
import 'data/repository/country_repository_impl.dart';
import 'domain/repository/country_repository.dart';
import 'domain/usecase/country_delete.dart';
import 'domain/usecase/country_getlist.dart';
import 'domain/usecase/country_post.dart';
import 'domain/usecase/country_put.dart';
import 'presentation/bloc/country_bloc.dart';
import 'presentation/page/country_page.dart';

/// Módulo da interface 'countries' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md, padrão weberpsetes). Montado como ModuleRoute
/// filho do Home; o título chega via arguments (nome da interface no menu),
/// com fallback pelo catálogo para refresh direto na URL.
class CountriesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CountryDatasource>(
            (i) => CountryDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CountryRepository>(
            (i) => CountryRepositoryImpl(datasource: i.get<CountryDatasource>())),
        Bind.factory<CountryGetlist>(
            (i) => CountryGetlist(repository: i.get<CountryRepository>())),
        Bind.factory<CountryPost>(
            (i) => CountryPost(repository: i.get<CountryRepository>())),
        Bind.factory<CountryPut>(
            (i) => CountryPut(repository: i.get<CountryRepository>())),
        Bind.factory<CountryDelete>(
            (i) => CountryDelete(repository: i.get<CountryRepository>())),
        Bind.singleton<CountryBloc>((i) => CountryBloc(
              getlist: i.get<CountryGetlist>(),
              post:    i.get<CountryPost>(),
              put:     i.get<CountryPut>(),
              delete:  i.get<CountryDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CountryPage(
              title: args.data as String? ??
                  trCatalog('countries', 'Countries', prefix: 'menu.interfaces'),
            )),
      ];
}
