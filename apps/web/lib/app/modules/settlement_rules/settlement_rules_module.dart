import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/settlement_rule_datasource.dart';
import 'data/datasource/settlement_rule_lookup_datasource.dart';
import 'data/repository/settlement_rule_repository_impl.dart';
import 'domain/repository/settlement_rule_repository.dart';
import 'domain/usecase/settlement_rule_delete.dart';
import 'domain/usecase/settlement_rule_get.dart';
import 'domain/usecase/settlement_rule_getlist.dart';
import 'domain/usecase/settlement_rule_post.dart';
import 'domain/usecase/settlement_rule_put.dart';
import 'presentation/bloc/settlement_rule_bloc.dart';
import 'presentation/page/settlement_rule_page.dart';

/// Módulo da interface 'settlement-rules' — Regras de Recebimento
/// (baixa automática por forma de pagamento; prompt_contrato_financeiro_
/// baixa_automatica.md D1–D22). Grupo Financeiro. Gêmeo do
/// /api/settlement-rules na setes-api (1 interface = 1 módulo).
class SettlementRulesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<SettlementRuleDatasource>((i) =>
            SettlementRuleDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups DEDICADOS do form (a page só toca este datasource).
        Bind.lazySingleton<SettlementRuleLookupDatasource>((i) =>
            SettlementRuleLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<SettlementRuleRepository>((i) =>
            SettlementRuleRepositoryImpl(
                datasource: i.get<SettlementRuleDatasource>())),
        Bind.factory<SettlementRuleGetlist>((i) => SettlementRuleGetlist(
            repository: i.get<SettlementRuleRepository>())),
        Bind.factory<SettlementRuleGet>((i) => SettlementRuleGet(
            repository: i.get<SettlementRuleRepository>())),
        Bind.factory<SettlementRulePost>((i) => SettlementRulePost(
            repository: i.get<SettlementRuleRepository>())),
        Bind.factory<SettlementRulePut>((i) => SettlementRulePut(
            repository: i.get<SettlementRuleRepository>())),
        Bind.factory<SettlementRuleDelete>((i) => SettlementRuleDelete(
            repository: i.get<SettlementRuleRepository>())),
        Bind.singleton<SettlementRuleBloc>((i) => SettlementRuleBloc(
              getlist: i.get<SettlementRuleGetlist>(),
              get:     i.get<SettlementRuleGet>(),
              post:    i.get<SettlementRulePost>(),
              put:     i.get<SettlementRulePut>(),
              delete:  i.get<SettlementRuleDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => SettlementRulePage(
              title: args.data as String? ??
                  trCatalog('settlement-rules', 'Financial Contracts',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
