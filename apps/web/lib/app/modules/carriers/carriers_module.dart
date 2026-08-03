import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/entity/data/entity_by_document_datasource.dart';
import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/carrier_datasource.dart';
import 'data/repository/carrier_repository_impl.dart';
import 'domain/repository/carrier_repository.dart';
import 'domain/usecase/carrier_delete.dart';
import 'domain/usecase/carrier_get.dart';
import 'domain/usecase/carrier_getlist.dart';
import 'domain/usecase/carrier_post.dart';
import 'domain/usecase/carrier_put.dart';
import 'presentation/bloc/carrier_bloc.dart';
import 'presentation/page/carrier_page.dart';

/// Módulo da interface 'carriers' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Onda 2 da Entidade Única
/// (prompt_onda2_salesman_carrier.md): molde collaborator + aba Tributação
/// compartilhada (D2) — abas de app/shared/entity, lookups de
/// app/shared/lookup; módulo NUNCA importa módulo (regra de promoção).
class CarriersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CarrierDatasource>(
            (i) => CarrierDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CarrierRepository>((i) =>
            CarrierRepositoryImpl(datasource: i.get<CarrierDatasource>())),
        Bind.factory<CarrierGetlist>(
            (i) => CarrierGetlist(repository: i.get<CarrierRepository>())),
        Bind.factory<CarrierGet>(
            (i) => CarrierGet(repository: i.get<CarrierRepository>())),
        Bind.factory<CarrierPost>(
            (i) => CarrierPost(repository: i.get<CarrierRepository>())),
        Bind.factory<CarrierPut>(
            (i) => CarrierPut(repository: i.get<CarrierRepository>())),
        Bind.factory<CarrierDelete>(
            (i) => CarrierDelete(repository: i.get<CarrierRepository>())),
        Bind.singleton<CarrierBloc>((i) => CarrierBloc(
              getlist: i.get<CarrierGetlist>(),
              get:     i.get<CarrierGet>(),
              post:    i.get<CarrierPost>(),
              put:     i.get<CarrierPut>(),
              delete:  i.get<CarrierDelete>(),
            )),
        // Prefill by-document na criação (Fase 3, decisões 3, 9 e 10)
        Bind.lazySingleton<EntityByDocumentDatasource>(
            (i) => EntityByDocumentDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups (shared) — FKs da aba de Endereços (campo-lookup-fk.md)
        Bind.lazySingleton<CountryLookupDatasource>(
            (i) => CountryLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<StateLookupDatasource>(
            (i) => StateLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CityLookupDatasource>(
            (i) => CityLookupDatasourceImpl(client: i.get<ApiClient>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CarrierPage(
              title: args.data as String? ??
                  trCatalog('carriers', 'Carriers',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
