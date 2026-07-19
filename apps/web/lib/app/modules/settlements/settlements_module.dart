import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/settlement_datasource.dart';
import 'data/repository/settlement_repository_impl.dart';
import 'domain/repository/settlement_repository.dart';
import 'domain/usecase/settlement_bills_getlist.dart';
import 'domain/usecase/settlement_reversal.dart';
import 'domain/usecase/settlement_settle.dart';
import 'domain/usecase/settlement_settled_getlist.dart';
import 'domain/usecase/settlement_statements_get.dart';
import 'presentation/bloc/settlement_bloc.dart';
import 'presentation/page/settlement_page.dart';

/// Módulo da interface 'settlements' — Baixa de Títulos (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Módulo Software House, Onda 5: 2ª
/// TELA DE PROCESSO do produto — carteira de títulos, baixa em lote
/// (N títulos → 1 código → 1 movimento), estorno imutável e extrato.
/// Gêmeo do /api/settlements na setes-api.
class SettlementsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<SettlementDatasource>(
            (i) => SettlementDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<SettlementRepository>((i) =>
            SettlementRepositoryImpl(
                datasource: i.get<SettlementDatasource>())),
        Bind.factory<SettlementBillsGetlist>((i) => SettlementBillsGetlist(
            repository: i.get<SettlementRepository>())),
        Bind.factory<SettlementSettle>((i) =>
            SettlementSettle(repository: i.get<SettlementRepository>())),
        Bind.factory<SettlementSettledGetlist>((i) => SettlementSettledGetlist(
            repository: i.get<SettlementRepository>())),
        Bind.factory<SettlementReversal>((i) =>
            SettlementReversal(repository: i.get<SettlementRepository>())),
        Bind.factory<SettlementStatementsGet>((i) => SettlementStatementsGet(
            repository: i.get<SettlementRepository>())),
        Bind.singleton<SettlementBloc>((i) => SettlementBloc(
              billsGetlist:   i.get<SettlementBillsGetlist>(),
              settle:         i.get<SettlementSettle>(),
              settledGetlist: i.get<SettlementSettledGetlist>(),
              reversal:       i.get<SettlementReversal>(),
              statementsGet:  i.get<SettlementStatementsGet>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => SettlementPage(
              title: args.data as String? ??
                  trCatalog('settlements', 'Settlements',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
