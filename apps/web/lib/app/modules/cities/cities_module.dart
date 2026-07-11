import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/city_datasource.dart';
import 'data/repository/city_repository_impl.dart';
import 'domain/repository/city_repository.dart';
import 'domain/usecase/city_delete.dart';
import 'domain/usecase/city_getlist.dart';
import 'domain/usecase/city_post.dart';
import 'domain/usecase/city_put.dart';
import 'presentation/bloc/city_bloc.dart';
import 'presentation/page/city_page.dart';

/// Módulo da interface 'cities' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md, padrão weberpsetes). O lookup de Estado vem do
/// app/shared/lookup — módulo NUNCA importa módulo (regra de promoção).
class CitiesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CityDatasource>(
            (i) => CityDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CityRepository>(
            (i) => CityRepositoryImpl(datasource: i.get<CityDatasource>())),
        Bind.factory<CityGetlist>(
            (i) => CityGetlist(repository: i.get<CityRepository>())),
        Bind.factory<CityPost>(
            (i) => CityPost(repository: i.get<CityRepository>())),
        Bind.factory<CityPut>(
            (i) => CityPut(repository: i.get<CityRepository>())),
        Bind.factory<CityDelete>(
            (i) => CityDelete(repository: i.get<CityRepository>())),
        Bind.singleton<CityBloc>((i) => CityBloc(
              getlist: i.get<CityGetlist>(),
              post:    i.get<CityPost>(),
              put:     i.get<CityPut>(),
              delete:  i.get<CityDelete>(),
            )),
        // Lookup de Estado (shared) — lista de apoio da FK tb_state_id
        Bind.lazySingleton<StateLookupDatasource>(
            (i) => StateLookupDatasourceImpl(client: i.get<ApiClient>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CityPage(
              title: args.data as String? ??
                  trCatalog('cities', 'Cities', prefix: 'menu.interfaces'),
            )),
      ];
}
