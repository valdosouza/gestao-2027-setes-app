import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/lookup/datasource/state_lookup_datasource.dart';
import 'data/datasource/cfop_lookup_datasource.dart';
import 'data/datasource/tax_rule_datasource.dart';
import 'data/repository/tax_rule_repository_impl.dart';
import 'domain/repository/tax_rule_repository.dart';
import 'domain/usecase/tax_rule_delete.dart';
import 'domain/usecase/tax_rule_get.dart';
import 'domain/usecase/tax_rule_get_catalogs.dart';
import 'domain/usecase/tax_rule_getlist.dart';
import 'domain/usecase/tax_rule_post.dart';
import 'domain/usecase/tax_rule_put.dart';
import 'presentation/bloc/tax_rule_bloc.dart';
import 'presentation/page/tax_rule_page.dart';

/// Módulo da interface 'tax-rules' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Cadastro do CLIENTE (fase Faturamento Fiscal e
/// Financeiro): /api/tax-rules com escopo por institution no JWT.
/// O lookup de Estado (UF do seletor) vem de app/shared/lookup —
/// bind no módulo de quem usa (skill campo-lookup-fk.md).
class TaxRulesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<TaxRuleDatasource>(
            (i) => TaxRuleDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CfopLookupDatasource>(
            (i) => CfopLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<TaxRuleRepository>((i) =>
            TaxRuleRepositoryImpl(datasource: i.get<TaxRuleDatasource>())),
        Bind.lazySingleton<StateLookupDatasource>(
            (i) => StateLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.factory<TaxRuleGetlist>(
            (i) => TaxRuleGetlist(repository: i.get<TaxRuleRepository>())),
        Bind.factory<TaxRuleGet>(
            (i) => TaxRuleGet(repository: i.get<TaxRuleRepository>())),
        Bind.factory<TaxRuleGetCatalogs>((i) =>
            TaxRuleGetCatalogs(repository: i.get<TaxRuleRepository>())),
        Bind.factory<TaxRulePost>(
            (i) => TaxRulePost(repository: i.get<TaxRuleRepository>())),
        Bind.factory<TaxRulePut>(
            (i) => TaxRulePut(repository: i.get<TaxRuleRepository>())),
        Bind.factory<TaxRuleDelete>(
            (i) => TaxRuleDelete(repository: i.get<TaxRuleRepository>())),
        Bind.singleton<TaxRuleBloc>((i) => TaxRuleBloc(
              getlist:     i.get<TaxRuleGetlist>(),
              get:         i.get<TaxRuleGet>(),
              getCatalogs: i.get<TaxRuleGetCatalogs>(),
              post:        i.get<TaxRulePost>(),
              put:         i.get<TaxRulePut>(),
              delete:      i.get<TaxRuleDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => TaxRulePage(
              title: args.data as String? ??
                  trCatalog('tax-rules', 'Tax Rule',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
