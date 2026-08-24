import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/cashier_datasource.dart';
import 'data/repository/cashier_repository_impl.dart';
import 'domain/repository/cashier_repository.dart';
import 'domain/usecase/cashier_close.dart';
import 'domain/usecase/cashier_current_get.dart';
import 'domain/usecase/cashier_detail_get.dart';
import 'domain/usecase/cashier_open.dart';
import 'domain/usecase/cashier_withdraw.dart';
import 'presentation/bloc/cashier_bloc.dart';
import 'presentation/page/cashier_page.dart';

/// Módulo da interface 'cashier' — Abertura/Fechamento de Caixa (1
/// interface = 1 módulo, ARQUITETURA_MODULOS.md). 3º TIPO de tela do
/// produto (skill tela-de-processo.md): SESSÃO/STATUS, não lista+form nem
/// árvore. Gêmeo do /api/cashier na setes-api (W3.2).
class CashierModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CashierDatasource>(
            (i) => CashierDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CashierRepository>((i) =>
            CashierRepositoryImpl(datasource: i.get<CashierDatasource>())),
        Bind.factory<CashierCurrentGet>(
            (i) => CashierCurrentGet(repository: i.get<CashierRepository>())),
        Bind.factory<CashierOpen>(
            (i) => CashierOpen(repository: i.get<CashierRepository>())),
        Bind.factory<CashierDetailGet>(
            (i) => CashierDetailGet(repository: i.get<CashierRepository>())),
        Bind.factory<CashierWithdraw>(
            (i) => CashierWithdraw(repository: i.get<CashierRepository>())),
        Bind.factory<CashierClose>(
            (i) => CashierClose(repository: i.get<CashierRepository>())),
        Bind.singleton<CashierBloc>((i) => CashierBloc(
              currentGet: i.get<CashierCurrentGet>(),
              open:       i.get<CashierOpen>(),
              detailGet:  i.get<CashierDetailGet>(),
              withdraw:   i.get<CashierWithdraw>(),
              closeCashier: i.get<CashierClose>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CashierPage(
              title: args.data as String? ??
                  trCatalog('cashier', 'Cashier', prefix: 'menu.interfaces'),
            )),
      ];
}
