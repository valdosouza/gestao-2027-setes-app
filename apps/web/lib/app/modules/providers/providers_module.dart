import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/entity/data/entity_by_document_datasource.dart';
import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/provider_datasource.dart';
import 'data/repository/provider_repository_impl.dart';
import 'domain/repository/provider_repository.dart';
import 'domain/usecase/provider_delete.dart';
import 'domain/usecase/provider_get.dart';
import 'domain/usecase/provider_getlist.dart';
import 'domain/usecase/provider_post.dart';
import 'domain/usecase/provider_put.dart';
import 'presentation/bloc/provider_bloc.dart';
import 'presentation/page/provider_page.dart';

/// Módulo da interface 'providers' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Onda 3 da Entidade Única
/// (prompt_onda3_provider.md): espelho do carrier da Onda 2 — cadeia
/// fiscal completa + aba Tributação compartilhada (D1) — abas de
/// app/shared/entity, lookups de app/shared/lookup; módulo NUNCA importa
/// módulo (regra de promoção).
class ProvidersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ProviderDatasource>(
            (i) => ProviderDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ProviderRepository>((i) =>
            ProviderRepositoryImpl(datasource: i.get<ProviderDatasource>())),
        Bind.factory<ProviderGetlist>(
            (i) => ProviderGetlist(repository: i.get<ProviderRepository>())),
        Bind.factory<ProviderGet>(
            (i) => ProviderGet(repository: i.get<ProviderRepository>())),
        Bind.factory<ProviderPost>(
            (i) => ProviderPost(repository: i.get<ProviderRepository>())),
        Bind.factory<ProviderPut>(
            (i) => ProviderPut(repository: i.get<ProviderRepository>())),
        Bind.factory<ProviderDelete>(
            (i) => ProviderDelete(repository: i.get<ProviderRepository>())),
        Bind.singleton<ProviderBloc>((i) => ProviderBloc(
              getlist: i.get<ProviderGetlist>(),
              get:     i.get<ProviderGet>(),
              post:    i.get<ProviderPost>(),
              put:     i.get<ProviderPut>(),
              delete:  i.get<ProviderDelete>(),
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
        ChildRoute('/', child: (_, args) => ProviderPage(
              title: args.data as String? ??
                  trCatalog('providers', 'Providers',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
