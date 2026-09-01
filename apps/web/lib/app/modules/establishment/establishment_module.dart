import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/establishment_datasource.dart';
import 'data/repository/establishment_repository_impl.dart';
import 'domain/repository/establishment_repository.dart';
import 'domain/usecase/establishment_get.dart';
import 'domain/usecase/establishment_put.dart';
import 'presentation/bloc/establishment_bloc.dart';
import 'presentation/page/establishment_page.dart';

/// Módulo da interface 'establishment' — menu Sistema, "Meu Estabelecimento"
/// (ARQUITETURA_MODULOS.md: 1 interface = 1 módulo). CRUD comum SEM lista
/// (parecer setes-conceito 2026-08-25): a API garante cardinalidade 1 via
/// token — NUNCA existe `:id` na URL. Reaproveita os lookups de país/UF/
/// cidade de app/shared/lookup (mesmos da aba Endereços de `institutions`) —
/// módulo NUNCA importa módulo (regra de promoção).
class EstablishmentModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<EstablishmentDatasource>(
            (i) => EstablishmentDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<EstablishmentRepository>((i) =>
            EstablishmentRepositoryImpl(
                datasource: i.get<EstablishmentDatasource>())),
        Bind.factory<EstablishmentGet>((i) =>
            EstablishmentGet(repository: i.get<EstablishmentRepository>())),
        Bind.factory<EstablishmentPut>((i) =>
            EstablishmentPut(repository: i.get<EstablishmentRepository>())),
        Bind.singleton<EstablishmentBloc>((i) => EstablishmentBloc(
              get: i.get<EstablishmentGet>(),
              put: i.get<EstablishmentPut>(),
            )),
        // Lookups (shared) — FKs da aba de Endereços (campo-lookup-fk.md).
        Bind.lazySingleton<CountryLookupDatasource>(
            (i) => CountryLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<StateLookupDatasource>(
            (i) => StateLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CityLookupDatasource>(
            (i) => CityLookupDatasourceImpl(client: i.get<ApiClient>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => EstablishmentPage(
              title: args.data as String? ??
                  trCatalog('establishment', 'My Establishment',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
