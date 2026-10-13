// Monta o ServiceOrderBloc com os TRÊS repositórios do módulo (F2b — D-F139):
// a OS (/api/service-orders), a NFS-e (nfse-api) e os fatos do ERP sobre a
// nota (/api/billing). Os testes passam mocks; o que não interessa ao teste
// recebe um mock vazio (chamá-lo falha alto — mocktail sem stub).
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_invoice_repository.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_nfse_repository.dart';
import 'package:setes_web/app/modules/service_orders/domain/repository/service_order_repository.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_batch_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_plan_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_delete.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_danfse.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_effect_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_pending.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_reconfirm.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_refresh.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_waive_cancel.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_xml.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_get.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_getlist.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_item_delete.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_item_save.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_monthly_run.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_post.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_transmit.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

class ServiceOrderRepoMock extends Mock implements ServiceOrderRepository {}

class NfseRepoMock extends Mock implements ServiceOrderNfseRepository {}

class InvoiceRepoMock extends Mock implements ServiceOrderInvoiceRepository {}

ServiceOrderBloc buildServiceOrderBloc({
  ServiceOrderRepository? repo,
  ServiceOrderNfseRepository? nfse,
  ServiceOrderInvoiceRepository? invoice,
}) {
  final r = repo ?? ServiceOrderRepoMock();
  final n = nfse ?? NfseRepoMock();
  final i = invoice ?? InvoiceRepoMock();
  return ServiceOrderBloc(
    getlist: ServiceOrderGetlist(repository: r),
    get: ServiceOrderGet(repository: r),
    post: ServiceOrderPost(repository: r),
    delete: ServiceOrderDelete(repository: r),
    itemSave: ServiceOrderItemSave(repository: r),
    itemDelete: ServiceOrderItemDelete(repository: r),
    monthlyRun: ServiceOrderMonthlyRun(repository: r),
    invoice: ServiceOrderInvoice(repository: r),
    batchInvoice: ServiceOrderBatchInvoice(repository: r),
    fiscalGet: ServiceOrderFiscalGet(repository: n),
    fiscalEffectGet: ServiceOrderFiscalEffectGet(repository: i),
    cancelPlanGet: ServiceOrderCancelPlanGet(repository: i),
    cancelInvoice: ServiceOrderCancelInvoice(nfse: n, invoice: i),
    transmit: ServiceOrderTransmit(repository: n),
    fiscalRefresh: ServiceOrderFiscalRefresh(repository: n),
    fiscalReconfirm: ServiceOrderFiscalReconfirm(repository: n),
    fiscalXml: ServiceOrderFiscalXml(repository: n),
    fiscalDanfse: ServiceOrderFiscalDanfse(repository: n),
    fiscalPending: ServiceOrderFiscalPendingList(repository: n),
    fiscalTransmitBatch: ServiceOrderFiscalTransmitBatch(repository: n),
    fiscalWaiveCancel: ServiceOrderFiscalWaiveCancel(repository: i),
  );
}
