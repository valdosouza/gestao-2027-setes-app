import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/search/search_criteria_datasource.dart';
import 'data/datasource/service_order_datasource.dart';
import 'data/datasource/service_order_invoice_datasource.dart';
import 'data/datasource/service_order_nfse_datasource.dart';
import 'data/repository/service_order_invoice_repository_impl.dart';
import 'data/repository/service_order_nfse_repository_impl.dart';
import 'data/repository/service_order_repository_impl.dart';
import 'domain/repository/service_order_invoice_repository.dart';
import 'domain/repository/service_order_nfse_repository.dart';
import 'domain/repository/service_order_repository.dart';
import 'domain/usecase/service_order_cancel_plan_get.dart';
import 'domain/usecase/service_order_delete.dart';
import 'domain/usecase/service_order_fiscal_danfse.dart';
import 'domain/usecase/service_order_fiscal_effect_get.dart';
import 'domain/usecase/service_order_fiscal_get.dart';
import 'domain/usecase/service_order_fiscal_pending.dart';
import 'domain/usecase/service_order_fiscal_reconfirm.dart';
import 'domain/usecase/service_order_fiscal_refresh.dart';
import 'domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'domain/usecase/service_order_fiscal_waive_cancel.dart';
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
///
/// F2b (D-F4/D-F139): a NFS-e da OS faturada fala com a nfse-api por um
/// datasource DEDICADO ([ServiceOrderNfseDatasource] — [NfseApiClient]); os
/// fatos do ERP sobre a nota (plano, efeito, cancelar, manter) pelo
/// [ServiceOrderInvoiceDatasource] (/api/billing — exceção nomeada). Nunca
/// cruzam; a saga do cancelamento compõe os dois REPOSITÓRIOS.
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
        Bind.factory<ServiceOrderBatchInvoice>((i) => ServiceOrderBatchInvoice(
            repository: i.get<ServiceOrderRepository>())),
        // F2b — a NFS-e na nfse-api (D-F4: datasource dedicado, NfseApiClient)
        Bind.lazySingleton<ServiceOrderNfseDatasource>((i) =>
            ServiceOrderNfseDatasourceImpl(client: i.get<NfseApiClient>())),
        Bind.lazySingleton<ServiceOrderNfseRepository>((i) =>
            ServiceOrderNfseRepositoryImpl(
                datasource: i.get<ServiceOrderNfseDatasource>())),
        // F2b — os fatos do ERP sobre a nota (/api/billing — D-F115)
        Bind.lazySingleton<ServiceOrderInvoiceDatasource>((i) =>
            ServiceOrderInvoiceDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ServiceOrderInvoiceRepository>((i) =>
            ServiceOrderInvoiceRepositoryImpl(
                datasource: i.get<ServiceOrderInvoiceDatasource>())),
        Bind.factory<ServiceOrderFiscalGet>((i) => ServiceOrderFiscalGet(
            repository: i.get<ServiceOrderNfseRepository>())),
        Bind.factory<ServiceOrderFiscalEffectGet>((i) =>
            ServiceOrderFiscalEffectGet(
                repository: i.get<ServiceOrderInvoiceRepository>())),
        Bind.factory<ServiceOrderCancelPlanGet>((i) => ServiceOrderCancelPlanGet(
            repository: i.get<ServiceOrderInvoiceRepository>())),
        Bind.factory<ServiceOrderTransmit>((i) => ServiceOrderTransmit(
            repository: i.get<ServiceOrderNfseRepository>())),
        Bind.factory<ServiceOrderFiscalRefresh>((i) => ServiceOrderFiscalRefresh(
            repository: i.get<ServiceOrderNfseRepository>())),
        Bind.factory<ServiceOrderFiscalReconfirm>((i) =>
            ServiceOrderFiscalReconfirm(
                repository: i.get<ServiceOrderNfseRepository>())),
        Bind.factory<ServiceOrderFiscalXml>((i) => ServiceOrderFiscalXml(
            repository: i.get<ServiceOrderNfseRepository>())),
        Bind.factory<ServiceOrderFiscalDanfse>((i) => ServiceOrderFiscalDanfse(
            repository: i.get<ServiceOrderNfseRepository>())),
        // D-F139: a SAGA do cancelamento compõe os DOIS repositórios
        Bind.factory<ServiceOrderCancelInvoice>((i) => ServiceOrderCancelInvoice(
              nfse: i.get<ServiceOrderNfseRepository>(),
              invoice: i.get<ServiceOrderInvoiceRepository>(),
            )),
        Bind.factory<ServiceOrderFiscalWaiveCancel>((i) =>
            ServiceOrderFiscalWaiveCancel(
                repository: i.get<ServiceOrderInvoiceRepository>())),
        Bind.factory<ServiceOrderFiscalPendingList>((i) =>
            ServiceOrderFiscalPendingList(
                repository: i.get<ServiceOrderNfseRepository>())),
        Bind.factory<ServiceOrderFiscalTransmitBatch>((i) =>
            ServiceOrderFiscalTransmitBatch(
                repository: i.get<ServiceOrderNfseRepository>())),
        Bind.singleton<ServiceOrderBloc>((i) => ServiceOrderBloc(
              getlist:    i.get<ServiceOrderGetlist>(),
              get:        i.get<ServiceOrderGet>(),
              post:       i.get<ServiceOrderPost>(),
              delete:     i.get<ServiceOrderDelete>(),
              itemSave:   i.get<ServiceOrderItemSave>(),
              itemDelete: i.get<ServiceOrderItemDelete>(),
              monthlyRun: i.get<ServiceOrderMonthlyRun>(),
              invoice:    i.get<ServiceOrderInvoice>(),
              batchInvoice:  i.get<ServiceOrderBatchInvoice>(),
              fiscalGet:     i.get<ServiceOrderFiscalGet>(),
              fiscalEffectGet: i.get<ServiceOrderFiscalEffectGet>(),
              cancelPlanGet: i.get<ServiceOrderCancelPlanGet>(),
              cancelInvoice: i.get<ServiceOrderCancelInvoice>(),
              transmit:      i.get<ServiceOrderTransmit>(),
              fiscalRefresh: i.get<ServiceOrderFiscalRefresh>(),
              fiscalReconfirm: i.get<ServiceOrderFiscalReconfirm>(),
              fiscalXml:     i.get<ServiceOrderFiscalXml>(),
              fiscalDanfse:  i.get<ServiceOrderFiscalDanfse>(),
              fiscalPending: i.get<ServiceOrderFiscalPendingList>(),
              fiscalTransmitBatch: i.get<ServiceOrderFiscalTransmitBatch>(),
              fiscalWaiveCancel:   i.get<ServiceOrderFiscalWaiveCancel>(),
            ),
            // D-F156 (= Q-F164 (a), Valdo 2026-10-13 — F2B-ADV-03): o Modular 5
            // só descarta Disposable/onDispose — sem isto o bloc NUNCA fechava.
            // Fechar corta os dois lotes entre uma unidade e a próxima (o fiscal
            // depois da nota em voo — D-F145; o de faturamento entre blocos —
            // decide a Q-R5.2); o que já foi feito fica na lista
            onDispose: (bloc) {
              bloc.stopBatches();
              bloc.close();
            }),
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
