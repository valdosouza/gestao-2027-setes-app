import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/search/search_criteria_datasource.dart';
import 'data/datasource/service_order_datasource.dart';
import 'data/datasource/service_order_fiscal_datasource.dart';
import 'data/repository/service_order_fiscal_repository_impl.dart';
import 'data/repository/service_order_repository_impl.dart';
import 'domain/repository/service_order_fiscal_repository.dart';
import 'domain/repository/service_order_repository.dart';
import 'domain/usecase/service_order_delete.dart';
import 'domain/usecase/service_order_fiscal_cancel.dart';
import 'domain/usecase/service_order_fiscal_danfse.dart';
import 'domain/usecase/service_order_fiscal_get.dart';
import 'domain/usecase/service_order_fiscal_pending.dart';
import 'domain/usecase/service_order_fiscal_refresh.dart';
import 'domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'domain/usecase/service_order_fiscal_xml.dart';
import 'domain/usecase/service_order_transmit.dart';
import 'domain/usecase/service_order_get.dart';
import 'domain/usecase/service_order_getlist.dart';
import 'domain/usecase/service_order_batch_invoice.dart';
import 'domain/usecase/service_order_cancel_invoice.dart';
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
        // Pesquisa avançada (D-BA2) — amarrada ao /api do PRÓPRIO módulo
        Bind.lazySingleton<SearchCriteriaDatasource>((i) =>
            SearchCriteriaDatasourceImpl(
                client: i.get<ApiClient>(), basePath: '/api/service-orders')),
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
        Bind.factory<ServiceOrderCancelInvoice>((i) => ServiceOrderCancelInvoice(
            repository: i.get<ServiceOrderRepository>())),
        Bind.factory<ServiceOrderBatchInvoice>((i) => ServiceOrderBatchInvoice(
            repository: i.get<ServiceOrderRepository>())),
        // Onda 3 — NFS-e pelo ADN: datasource dedicado (/api/billing/fiscal*)
        Bind.lazySingleton<ServiceOrderFiscalDatasource>((i) =>
            ServiceOrderFiscalDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceOrderFiscalRepository>((i) =>
            ServiceOrderFiscalRepositoryImpl(
                datasource: i.get<ServiceOrderFiscalDatasource>())),
        Bind.factory<ServiceOrderFiscalGet>((i) => ServiceOrderFiscalGet(
            repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderTransmit>((i) => ServiceOrderTransmit(
            repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderFiscalRefresh>((i) => ServiceOrderFiscalRefresh(
            repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderFiscalXml>((i) => ServiceOrderFiscalXml(
            repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderFiscalDanfse>((i) => ServiceOrderFiscalDanfse(
            repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderFiscalCancel>((i) => ServiceOrderFiscalCancel(
            repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderFiscalPendingList>((i) =>
            ServiceOrderFiscalPendingList(
                repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.factory<ServiceOrderFiscalTransmitBatch>((i) =>
            ServiceOrderFiscalTransmitBatch(
                repository: i.get<ServiceOrderFiscalRepository>())),
        Bind.singleton<ServiceOrderBloc>((i) => ServiceOrderBloc(
              getlist:    i.get<ServiceOrderGetlist>(),
              get:        i.get<ServiceOrderGet>(),
              post:       i.get<ServiceOrderPost>(),
              delete:     i.get<ServiceOrderDelete>(),
              itemSave:   i.get<ServiceOrderItemSave>(),
              itemDelete: i.get<ServiceOrderItemDelete>(),
              monthlyRun: i.get<ServiceOrderMonthlyRun>(),
              invoice:    i.get<ServiceOrderInvoice>(),
              cancelInvoice: i.get<ServiceOrderCancelInvoice>(),
              batchInvoice:  i.get<ServiceOrderBatchInvoice>(),
              fiscalGet:     i.get<ServiceOrderFiscalGet>(),
              transmit:      i.get<ServiceOrderTransmit>(),
              fiscalRefresh: i.get<ServiceOrderFiscalRefresh>(),
              fiscalXml:     i.get<ServiceOrderFiscalXml>(),
              fiscalDanfse:  i.get<ServiceOrderFiscalDanfse>(),
              fiscalCancel:  i.get<ServiceOrderFiscalCancel>(),
              fiscalPending: i.get<ServiceOrderFiscalPendingList>(),
              fiscalTransmitBatch: i.get<ServiceOrderFiscalTransmitBatch>(),
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
