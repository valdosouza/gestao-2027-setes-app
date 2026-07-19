import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/service_order_datasource.dart';
import 'data/repository/service_order_repository_impl.dart';
import 'domain/repository/service_order_repository.dart';
import 'domain/usecase/service_order_delete.dart';
import 'domain/usecase/service_order_get.dart';
import 'domain/usecase/service_order_getlist.dart';
import 'domain/usecase/service_order_invoice.dart';
import 'domain/usecase/service_order_item_delete.dart';
import 'domain/usecase/service_order_item_save.dart';
import 'domain/usecase/service_order_monthly_run.dart';
import 'domain/usecase/service_order_post.dart';
import 'presentation/bloc/service_order_bloc.dart';
import 'presentation/page/service_order_page.dart';

/// Módulo da interface 'service-orders' — Ordens de Serviço (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Módulo Software House, Onda 4: 1ª
/// TELA DE PROCESSO do produto — ciclo mensal de faturamento (OS aberta
/// acumulando itens → rotina mensal → Gerar Faturamento). Gêmeo do
/// /api/service-orders na setes-api.
class ServiceOrdersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ServiceOrderDatasource>(
            (i) => ServiceOrderDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceOrderRepository>((i) =>
            ServiceOrderRepositoryImpl(
                datasource: i.get<ServiceOrderDatasource>())),
        Bind.factory<ServiceOrderGetlist>((i) =>
            ServiceOrderGetlist(repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderGet>((i) =>
            ServiceOrderGet(repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderPost>((i) =>
            ServiceOrderPost(repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderDelete>((i) =>
            ServiceOrderDelete(repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderItemSave>((i) =>
            ServiceOrderItemSave(repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderItemDelete>((i) => ServiceOrderItemDelete(
            repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderMonthlyRun>((i) => ServiceOrderMonthlyRun(
            repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderInvoice>((i) =>
            ServiceOrderInvoice(repository: i.get<ServiceOrderRepository>())),
        Bind.singleton<ServiceOrderBloc>((i) => ServiceOrderBloc(
              getlist:    i.get<ServiceOrderGetlist>(),
              get:        i.get<ServiceOrderGet>(),
              post:       i.get<ServiceOrderPost>(),
              delete:     i.get<ServiceOrderDelete>(),
              itemSave:   i.get<ServiceOrderItemSave>(),
              itemDelete: i.get<ServiceOrderItemDelete>(),
              monthlyRun: i.get<ServiceOrderMonthlyRun>(),
              invoice:    i.get<ServiceOrderInvoice>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => ServiceOrderPage(
              title: args.data as String? ??
                  trCatalog('service-orders', 'Service Orders',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
