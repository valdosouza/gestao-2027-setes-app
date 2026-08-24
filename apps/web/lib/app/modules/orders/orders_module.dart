import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/lookup/datasource/salesman_lookup_datasource.dart';
import 'data/datasource/order_datasource.dart';
import 'data/repository/order_repository_impl.dart';
import 'domain/repository/order_repository.dart';
import 'domain/usecase/order_billing_invoice.dart';
import 'domain/usecase/order_billing_validate.dart';
import 'domain/usecase/order_delete.dart';
import 'domain/usecase/order_get.dart';
import 'domain/usecase/order_getlist.dart';
import 'domain/usecase/order_item_delete.dart';
import 'domain/usecase/order_item_save.dart';
import 'domain/usecase/order_post.dart';
import 'domain/usecase/order_return_open.dart';
import 'presentation/bloc/order_bloc.dart';
import 'presentation/page/order_page.dart';

/// Módulo da interface 'orders' — Pedido de Venda / Conjugado (1 interface
/// = 1 módulo, ARQUITETURA_MODULOS.md). 2ª TELA DE PROCESSO do grupo
/// Vendas: pedido aberto acumulando itens (mercadoria e, por presença,
/// serviço) → Validar e Faturar chama /api/billing direto (sem módulo
/// billing próprio). Gêmeo do /api/orders na setes-api. Vendedor reusa o
/// shared/lookup/salesman_lookup_datasource (já usado por customers/
/// carriers/providers).
class OrdersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<OrderDatasource>(
            (i) => OrderDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<OrderRepository>(
            (i) => OrderRepositoryImpl(datasource: i.get<OrderDatasource>())),
        Bind.lazySingleton<SalesmanLookupDatasource>(
            (i) => SalesmanLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.factory<OrderGetlist>(
            (i) => OrderGetlist(repository: i.get<OrderRepository>())),
        Bind.factory<OrderGet>(
            (i) => OrderGet(repository: i.get<OrderRepository>())),
        Bind.factory<OrderPost>(
            (i) => OrderPost(repository: i.get<OrderRepository>())),
        Bind.factory<OrderDelete>(
            (i) => OrderDelete(repository: i.get<OrderRepository>())),
        Bind.factory<OrderItemSave>(
            (i) => OrderItemSave(repository: i.get<OrderRepository>())),
        Bind.factory<OrderItemDelete>(
            (i) => OrderItemDelete(repository: i.get<OrderRepository>())),
        Bind.factory<OrderBillingValidate>((i) =>
            OrderBillingValidate(repository: i.get<OrderRepository>())),
        Bind.factory<OrderBillingInvoiceUsecase>((i) =>
            OrderBillingInvoiceUsecase(repository: i.get<OrderRepository>())),
        Bind.factory<OrderReturnOpen>(
            (i) => OrderReturnOpen(repository: i.get<OrderRepository>())),
        Bind.singleton<OrderBloc>((i) => OrderBloc(
              getlist:         i.get<OrderGetlist>(),
              get:             i.get<OrderGet>(),
              post:            i.get<OrderPost>(),
              delete:          i.get<OrderDelete>(),
              itemSave:        i.get<OrderItemSave>(),
              itemDelete:      i.get<OrderItemDelete>(),
              billingValidate: i.get<OrderBillingValidate>(),
              billingInvoice:  i.get<OrderBillingInvoiceUsecase>(),
              returnOpen:      i.get<OrderReturnOpen>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => OrderPage(
              title: args.data as String? ??
                  trCatalog('orders', 'Orders', prefix: 'menu.interfaces'),
            )),
      ];
}
