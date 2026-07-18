import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/financial_plan_datasource.dart';
import 'data/repository/financial_plan_repository_impl.dart';
import 'domain/repository/financial_plan_repository.dart';
import 'domain/usecase/financial_plan_delete.dart';
import 'domain/usecase/financial_plan_getlist.dart';
import 'domain/usecase/financial_plan_post.dart';
import 'domain/usecase/financial_plan_put.dart';
import 'presentation/bloc/financial_plan_bloc.dart';
import 'presentation/page/financial_plan_page.dart';

/// Módulo da interface 'financial-plans' — Plano de Contas (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). 2º cadastro em ÁRVORE do produto
/// (padrão do tipo árvore — molde categories), grupo Cadastros.
class FinancialPlansModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<FinancialPlanDatasource>(
            (i) => FinancialPlanDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<FinancialPlanRepository>((i) =>
            FinancialPlanRepositoryImpl(
                datasource: i.get<FinancialPlanDatasource>())),
        Bind.factory<FinancialPlanGetlist>((i) =>
            FinancialPlanGetlist(repository: i.get<FinancialPlanRepository>())),
        Bind.factory<FinancialPlanPost>((i) =>
            FinancialPlanPost(repository: i.get<FinancialPlanRepository>())),
        Bind.factory<FinancialPlanPut>((i) =>
            FinancialPlanPut(repository: i.get<FinancialPlanRepository>())),
        Bind.factory<FinancialPlanDelete>((i) =>
            FinancialPlanDelete(repository: i.get<FinancialPlanRepository>())),
        Bind.singleton<FinancialPlanBloc>((i) => FinancialPlanBloc(
              getlist: i.get<FinancialPlanGetlist>(),
              post:    i.get<FinancialPlanPost>(),
              put:     i.get<FinancialPlanPut>(),
              delete:  i.get<FinancialPlanDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => FinancialPlanPage(
              title: args.data as String? ??
                  trCatalog('financial-plans', 'Financial Plans',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
