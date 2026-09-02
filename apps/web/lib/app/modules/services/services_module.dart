import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/service_datasource.dart';
import 'data/datasource/service_lookup_datasource.dart';
import 'data/repository/service_repository_impl.dart';
import 'domain/repository/service_repository.dart';
import 'domain/usecase/service_delete.dart';
import 'domain/usecase/service_get.dart';
import 'domain/usecase/service_getlist.dart';
import 'domain/usecase/service_post.dart';
import 'domain/usecase/service_price_lists_get.dart';
import 'domain/usecase/service_put.dart';
import 'presentation/bloc/service_bloc.dart';
import 'presentation/page/service_page.dart';

/// Módulo da interface 'services' — Cadastro de Serviços (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). prompt_modulo_services.md D1–D7:
/// tb_product kind='S' fixo na API (caminho individual — D5; tela irmã do
/// futuro cadastro de produtos — D6) + grade de preços por tabela (D4/D7).
/// Gêmeo do /api/services na setes-api.
class ServicesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ServiceDatasource>(
            (i) => ServiceDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceLookupDatasource>(
            (i) => ServiceLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceRepository>((i) =>
            ServiceRepositoryImpl(datasource: i.get<ServiceDatasource>())),
        Bind.factory<ServiceGetlist>(
            (i) => ServiceGetlist(repository: i.get<ServiceRepository>())),
        Bind.factory<ServiceGet>(
            (i) => ServiceGet(repository: i.get<ServiceRepository>())),
        Bind.factory<ServicePriceListsGet>((i) =>
            ServicePriceListsGet(repository: i.get<ServiceRepository>())),
        Bind.factory<ServicePost>(
            (i) => ServicePost(repository: i.get<ServiceRepository>())),
        Bind.factory<ServicePut>(
            (i) => ServicePut(repository: i.get<ServiceRepository>())),
        Bind.factory<ServiceDelete>(
            (i) => ServiceDelete(repository: i.get<ServiceRepository>())),
        Bind.singleton<ServiceBloc>((i) => ServiceBloc(
              getlist:       i.get<ServiceGetlist>(),
              get:           i.get<ServiceGet>(),
              getPriceLists: i.get<ServicePriceListsGet>(),
              post:          i.get<ServicePost>(),
              put:           i.get<ServicePut>(),
              delete:        i.get<ServiceDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => ServicePage(
              title: args.data as String? ??
                  trCatalog('services', 'Services', prefix: 'menu.interfaces'),
            )),
      ];
}
