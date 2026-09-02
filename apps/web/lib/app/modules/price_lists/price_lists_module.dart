import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/price_list_datasource.dart';
import 'data/repository/price_list_repository_impl.dart';
import 'domain/repository/price_list_repository.dart';
import 'domain/usecase/price_list_delete.dart';
import 'domain/usecase/price_list_get.dart';
import 'domain/usecase/price_list_getlist.dart';
import 'domain/usecase/price_list_post.dart';
import 'domain/usecase/price_list_put.dart';
import 'presentation/bloc/price_list_bloc.dart';
import 'presentation/page/price_list_page.dart';

/// Módulo da interface 'price-lists' — Tabelas de Preço (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). D7 do prompt_modulo_services.md:
/// tb_price_list no schema do cliente, consumida pela grade de preços do
/// cadastro de serviço. Gêmeo do /api/price-lists na setes-api.
class PriceListsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<PriceListDatasource>(
            (i) => PriceListDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<PriceListRepository>((i) =>
            PriceListRepositoryImpl(datasource: i.get<PriceListDatasource>())),
        Bind.factory<PriceListGetlist>(
            (i) => PriceListGetlist(repository: i.get<PriceListRepository>())),
        Bind.factory<PriceListGet>(
            (i) => PriceListGet(repository: i.get<PriceListRepository>())),
        Bind.factory<PriceListPost>(
            (i) => PriceListPost(repository: i.get<PriceListRepository>())),
        Bind.factory<PriceListPut>(
            (i) => PriceListPut(repository: i.get<PriceListRepository>())),
        Bind.factory<PriceListDelete>(
            (i) => PriceListDelete(repository: i.get<PriceListRepository>())),
        Bind.singleton<PriceListBloc>((i) => PriceListBloc(
              getlist: i.get<PriceListGetlist>(),
              get:     i.get<PriceListGet>(),
              post:    i.get<PriceListPost>(),
              put:     i.get<PriceListPut>(),
              delete:  i.get<PriceListDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => PriceListPage(
              title: args.data as String? ??
                  trCatalog('price-lists', 'Price Lists',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
