import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/entity/data/entity_by_document_datasource.dart';
import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/institution_datasource.dart';
import 'data/repository/institution_repository_impl.dart';
import 'domain/repository/institution_repository.dart';
import 'domain/usecase/institution_delete.dart';
import 'domain/usecase/institution_get.dart';
import 'domain/usecase/institution_getlist.dart';
import 'domain/usecase/institution_post.dart';
import 'domain/usecase/institution_put.dart';
import 'presentation/bloc/institution_bloc.dart';
import 'presentation/page/institution_page.dart';

/// Módulo da interface 'institutions' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Primeiro cadastro com cadeia de entidade
/// fiscal (skill cadastro-entidade-fiscal.md): as abas compartilhadas vêm
/// de app/shared/entity e os lookups de país/UF/cidade de app/shared/lookup
/// — módulo NUNCA importa módulo (regra de promoção).
class InstitutionsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<InstitutionDatasource>(
            (i) => InstitutionDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<InstitutionRepository>((i) =>
            InstitutionRepositoryImpl(
                datasource: i.get<InstitutionDatasource>())),
        Bind.factory<InstitutionGetlist>((i) =>
            InstitutionGetlist(repository: i.get<InstitutionRepository>())),
        Bind.factory<InstitutionGet>((i) =>
            InstitutionGet(repository: i.get<InstitutionRepository>())),
        Bind.factory<InstitutionPost>((i) =>
            InstitutionPost(repository: i.get<InstitutionRepository>())),
        Bind.factory<InstitutionPut>((i) =>
            InstitutionPut(repository: i.get<InstitutionRepository>())),
        Bind.factory<InstitutionDelete>((i) =>
            InstitutionDelete(repository: i.get<InstitutionRepository>())),
        Bind.singleton<InstitutionBloc>((i) => InstitutionBloc(
              getlist: i.get<InstitutionGetlist>(),
              get:     i.get<InstitutionGet>(),
              post:    i.get<InstitutionPost>(),
              put:     i.get<InstitutionPut>(),
              delete:  i.get<InstitutionDelete>(),
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
        ChildRoute('/', child: (_, args) => InstitutionPage(
              title: args.data as String? ??
                  trCatalog('institutions', 'Institutions',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
