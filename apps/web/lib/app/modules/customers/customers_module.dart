import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/entity/data/entity_by_document_datasource.dart';
import '../../shared/lookup/datasource/carrier_lookup_datasource.dart';
import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../shared/lookup/datasource/salesman_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/customer_datasource.dart';
import 'data/datasource/customer_partnership_datasource.dart';
import 'data/repository/customer_repository_impl.dart';
import 'domain/repository/customer_repository.dart';
import 'domain/usecase/customer_delete.dart';
import 'domain/usecase/customer_get.dart';
import 'domain/usecase/customer_getlist.dart';
import 'domain/usecase/customer_post.dart';
import 'domain/usecase/customer_put.dart';
import 'presentation/bloc/customer_bloc.dart';
import 'presentation/page/customer_page.dart';

/// Módulo da interface 'customers' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Primeiro papel novo da Fase 3 Entidade Única
/// (skill cadastro-entidade-fiscal.md): abas compartilhadas de
/// app/shared/entity, lookups de app/shared/lookup — módulo NUNCA importa
/// módulo (regra de promoção).
class CustomersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CustomerDatasource>(
            (i) => CustomerDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CustomerRepository>((i) =>
            CustomerRepositoryImpl(datasource: i.get<CustomerDatasource>())),
        Bind.factory<CustomerGetlist>((i) =>
            CustomerGetlist(repository: i.get<CustomerRepository>())),
        Bind.factory<CustomerGet>(
            (i) => CustomerGet(repository: i.get<CustomerRepository>())),
        Bind.factory<CustomerPost>(
            (i) => CustomerPost(repository: i.get<CustomerRepository>())),
        Bind.factory<CustomerPut>(
            (i) => CustomerPut(repository: i.get<CustomerRepository>())),
        Bind.factory<CustomerDelete>(
            (i) => CustomerDelete(repository: i.get<CustomerRepository>())),
        Bind.singleton<CustomerBloc>((i) => CustomerBloc(
              getlist: i.get<CustomerGetlist>(),
              get:     i.get<CustomerGet>(),
              post:    i.get<CustomerPost>(),
              put:     i.get<CustomerPut>(),
              delete:  i.get<CustomerDelete>(),
            )),
        // Prefill by-document na criação (Fase 3, decisões 3, 9 e 10)
        Bind.lazySingleton<EntityByDocumentDatasource>(
            (i) => EntityByDocumentDatasourceImpl(client: i.get<ApiClient>())),
        // Aba Parceria (Parceria v2 — angariação do cliente)
        Bind.lazySingleton<CustomerPartnershipDatasource>((i) =>
            CustomerPartnershipDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups (shared) — FKs da aba de Endereços (campo-lookup-fk.md)
        Bind.lazySingleton<CountryLookupDatasource>(
            (i) => CountryLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<StateLookupDatasource>(
            (i) => StateLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CityLookupDatasource>(
            (i) => CityLookupDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups da aba Cliente (Fase 3, decisão 11)
        Bind.lazySingleton<SalesmanLookupDatasource>(
            (i) => SalesmanLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CarrierLookupDatasource>(
            (i) => CarrierLookupDatasourceImpl(client: i.get<ApiClient>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CustomerPage(
              title: args.data as String? ??
                  trCatalog('customers', 'Customers',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
