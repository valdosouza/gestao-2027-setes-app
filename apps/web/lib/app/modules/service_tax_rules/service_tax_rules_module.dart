import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/service_tax_rule_datasource.dart';
import 'data/datasource/service_tax_rule_lookup_datasource.dart';
import 'data/repository/service_tax_rule_repository_impl.dart';
import 'domain/repository/service_tax_rule_repository.dart';
import 'domain/usecase/service_tax_rule_delete.dart';
import 'domain/usecase/service_tax_rule_get.dart';
import 'domain/usecase/service_tax_rule_getlist.dart';
import 'domain/usecase/service_tax_rule_post.dart';
import 'domain/usecase/service_tax_rule_put.dart';
import 'presentation/bloc/service_tax_rule_bloc.dart';
import 'presentation/page/service_tax_rule_page.dart';

/// Módulo da interface 'service-tax-rules' — Regras de Tributação de
/// Serviço (1 interface = 1 módulo, ARQUITETURA_MODULOS.md).
/// prompt_regra_tributacao_servico.md D1–D14: cidade de INCIDÊNCIA × item
/// da LC 116 → alíquota do ISS + código municipal (schema do cliente).
/// Gêmeo do /api/service-tax-rules na setes-api. Lookups de UF/cidade são
/// os compartilhados de app/shared/lookup (bind aqui, como os demais).
class ServiceTaxRulesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ServiceTaxRuleDatasource>(
            (i) => ServiceTaxRuleDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceTaxRuleLookupDatasource>((i) =>
            ServiceTaxRuleLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<StateLookupDatasource>(
            (i) => StateLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CityLookupDatasource>(
            (i) => CityLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceTaxRuleRepository>((i) =>
            ServiceTaxRuleRepositoryImpl(
                datasource: i.get<ServiceTaxRuleDatasource>())),
        Bind.factory<ServiceTaxRuleGetlist>((i) => ServiceTaxRuleGetlist(
            repository: i.get<ServiceTaxRuleRepository>())),
        Bind.factory<ServiceTaxRuleGet>((i) =>
            ServiceTaxRuleGet(repository: i.get<ServiceTaxRuleRepository>())),
        Bind.factory<ServiceTaxRulePost>((i) =>
            ServiceTaxRulePost(repository: i.get<ServiceTaxRuleRepository>())),
        Bind.factory<ServiceTaxRulePut>((i) =>
            ServiceTaxRulePut(repository: i.get<ServiceTaxRuleRepository>())),
        Bind.factory<ServiceTaxRuleDelete>((i) => ServiceTaxRuleDelete(
            repository: i.get<ServiceTaxRuleRepository>())),
        Bind.singleton<ServiceTaxRuleBloc>((i) => ServiceTaxRuleBloc(
              getlist: i.get<ServiceTaxRuleGetlist>(),
              get:     i.get<ServiceTaxRuleGet>(),
              post:    i.get<ServiceTaxRulePost>(),
              put:     i.get<ServiceTaxRulePut>(),
              delete:  i.get<ServiceTaxRuleDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => ServiceTaxRulePage(
              title: args.data as String? ??
                  trCatalog('service-tax-rules', 'Service Tax Rules',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
