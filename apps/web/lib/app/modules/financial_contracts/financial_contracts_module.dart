import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/financial_contract_datasource.dart';
import 'data/datasource/financial_contract_lookup_datasource.dart';
import 'data/repository/financial_contract_repository_impl.dart';
import 'domain/repository/financial_contract_repository.dart';
import 'domain/usecase/financial_contract_delete.dart';
import 'domain/usecase/financial_contract_get.dart';
import 'domain/usecase/financial_contract_getlist.dart';
import 'domain/usecase/financial_contract_post.dart';
import 'domain/usecase/financial_contract_put.dart';
import 'presentation/bloc/financial_contract_bloc.dart';
import 'presentation/page/financial_contract_page.dart';

/// Módulo da interface 'financial-contracts' — Contratos Financeiros
/// (baixa automática por forma de pagamento; prompt_contrato_financeiro_
/// baixa_automatica.md D1–D22). Grupo Financeiro. Gêmeo do
/// /api/financial-contracts na setes-api (1 interface = 1 módulo).
class FinancialContractsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<FinancialContractDatasource>((i) =>
            FinancialContractDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups DEDICADOS do form (a page só toca este datasource).
        Bind.lazySingleton<FinancialContractLookupDatasource>((i) =>
            FinancialContractLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<FinancialContractRepository>((i) =>
            FinancialContractRepositoryImpl(
                datasource: i.get<FinancialContractDatasource>())),
        Bind.factory<FinancialContractGetlist>((i) => FinancialContractGetlist(
            repository: i.get<FinancialContractRepository>())),
        Bind.factory<FinancialContractGet>((i) => FinancialContractGet(
            repository: i.get<FinancialContractRepository>())),
        Bind.factory<FinancialContractPost>((i) => FinancialContractPost(
            repository: i.get<FinancialContractRepository>())),
        Bind.factory<FinancialContractPut>((i) => FinancialContractPut(
            repository: i.get<FinancialContractRepository>())),
        Bind.factory<FinancialContractDelete>((i) => FinancialContractDelete(
            repository: i.get<FinancialContractRepository>())),
        Bind.singleton<FinancialContractBloc>((i) => FinancialContractBloc(
              getlist: i.get<FinancialContractGetlist>(),
              get:     i.get<FinancialContractGet>(),
              post:    i.get<FinancialContractPost>(),
              put:     i.get<FinancialContractPut>(),
              delete:  i.get<FinancialContractDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => FinancialContractPage(
              title: args.data as String? ??
                  trCatalog('financial-contracts', 'Financial Contracts',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
