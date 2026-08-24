import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/order_return_datasource.dart';
import 'data/repository/order_return_repository_impl.dart';
import 'domain/repository/order_return_repository.dart';
import 'domain/usecase/order_return_billing_invoice.dart';
import 'domain/usecase/order_return_billing_validate.dart';
import 'domain/usecase/order_return_delete.dart';
import 'domain/usecase/order_return_get.dart';
import 'domain/usecase/order_return_getlist.dart';
import 'domain/usecase/order_return_item_delete.dart';
import 'domain/usecase/order_return_item_quantity_put.dart';
import 'domain/usecase/order_return_post.dart';
import 'presentation/bloc/order_return_bloc.dart';
import 'presentation/page/order_return_page.dart';

/// Módulo da interface 'order-returns' — Devolução de Mercadoria (1
/// interface = 1 módulo, ARQUITETURA_MODULOS.md). TELA DE PROCESSO do
/// grupo Vendas (molde orders): a devolução é ajuste de ENTRADA ancorado
/// num pedido de venda FATURADO — nasce no módulo orders (ação
/// "Devolver"), aqui só se edita quantidade/remoção de itens, cancela e
/// fatura (/api/billing com adjustment { cfopId }). Gêmeo do
/// /api/order-returns na setes-api. Lookup de CFOP por projeção local em
/// /api/cfop (módulo nunca importa módulo).
class OrderReturnsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<OrderReturnDatasource>(
            (i) => OrderReturnDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<OrderReturnRepository>((i) =>
            OrderReturnRepositoryImpl(
                datasource: i.get<OrderReturnDatasource>())),
        Bind.factory<OrderReturnGetlist>((i) =>
            OrderReturnGetlist(repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnGet>(
            (i) => OrderReturnGet(repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnPost>(
            (i) => OrderReturnPost(repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnDelete>((i) =>
            OrderReturnDelete(repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnItemQuantityPut>((i) =>
            OrderReturnItemQuantityPut(
                repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnItemDelete>((i) =>
            OrderReturnItemDelete(repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnBillingValidate>((i) =>
            OrderReturnBillingValidate(
                repository: i.get<OrderReturnRepository>())),
        Bind.factory<OrderReturnBillingInvoiceUsecase>((i) =>
            OrderReturnBillingInvoiceUsecase(
                repository: i.get<OrderReturnRepository>())),
        Bind.singleton<OrderReturnBloc>((i) => OrderReturnBloc(
              getlist:         i.get<OrderReturnGetlist>(),
              get:             i.get<OrderReturnGet>(),
              post:            i.get<OrderReturnPost>(),
              delete:          i.get<OrderReturnDelete>(),
              itemQuantityPut: i.get<OrderReturnItemQuantityPut>(),
              itemDelete:      i.get<OrderReturnItemDelete>(),
              billingValidate: i.get<OrderReturnBillingValidate>(),
              billingInvoice:  i.get<OrderReturnBillingInvoiceUsecase>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => OrderReturnPage(
              title: args.data as String? ??
                  trCatalog('order-returns', 'Returns',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
