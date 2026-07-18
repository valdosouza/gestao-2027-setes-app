import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/entity/data/entity_by_document_datasource.dart';
import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/collaborator_datasource.dart';
import 'data/repository/collaborator_repository_impl.dart';
import 'domain/repository/collaborator_repository.dart';
import 'domain/usecase/collaborator_delete.dart';
import 'domain/usecase/collaborator_get.dart';
import 'domain/usecase/collaborator_getlist.dart';
import 'domain/usecase/collaborator_post.dart';
import 'domain/usecase/collaborator_put.dart';
import 'presentation/bloc/collaborator_bloc.dart';
import 'presentation/page/collaborator_page.dart';

/// Módulo da interface 'collaborators' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Onda 2 da Entidade Única (skill
/// cadastro-entidade-fiscal.md): mesmo desenho do customers SEM a aba
/// Tributação — abas compartilhadas de app/shared/entity, lookups de
/// app/shared/lookup; módulo NUNCA importa módulo (regra de promoção).
class CollaboratorsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CollaboratorDatasource>(
            (i) => CollaboratorDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CollaboratorRepository>((i) =>
            CollaboratorRepositoryImpl(
                datasource: i.get<CollaboratorDatasource>())),
        Bind.factory<CollaboratorGetlist>((i) =>
            CollaboratorGetlist(repository: i.get<CollaboratorRepository>())),
        Bind.factory<CollaboratorGet>(
            (i) => CollaboratorGet(repository: i.get<CollaboratorRepository>())),
        Bind.factory<CollaboratorPost>((i) =>
            CollaboratorPost(repository: i.get<CollaboratorRepository>())),
        Bind.factory<CollaboratorPut>(
            (i) => CollaboratorPut(repository: i.get<CollaboratorRepository>())),
        Bind.factory<CollaboratorDelete>((i) =>
            CollaboratorDelete(repository: i.get<CollaboratorRepository>())),
        Bind.singleton<CollaboratorBloc>((i) => CollaboratorBloc(
              getlist: i.get<CollaboratorGetlist>(),
              get:     i.get<CollaboratorGet>(),
              post:    i.get<CollaboratorPost>(),
              put:     i.get<CollaboratorPut>(),
              delete:  i.get<CollaboratorDelete>(),
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
        ChildRoute('/', child: (_, args) => CollaboratorPage(
              title: args.data as String? ??
                  trCatalog('collaborators', 'Collaborators',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
