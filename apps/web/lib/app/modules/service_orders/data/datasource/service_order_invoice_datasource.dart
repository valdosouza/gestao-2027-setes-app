import 'package:core/core.dart';

import '../../domain/entity/service_order_entity.dart';
import '../../domain/entity/service_order_fiscal_entity.dart';

/// Datasource dos FATOS DO ERP sobre a nota da OS — fala SÓ com o setes-api
/// (`/api/billing/*` — exceção nomeada da ARQUITETURA_MODULOS, D-F115): o
/// PLANO de cancelamento (consultivo — D-F128/D-F131), o EFEITO da voz do
/// fisco na nota (D-F114), o cancelamento da nota e o "manter a nota"
/// (D-F67). Nunca fala com a nfse-api (D-F4 — o fisco é do
/// [ServiceOrderNfseDatasource]).
abstract class ServiceOrderInvoiceDatasource {
  /// O MESMO plano do POST, sem gravar nada (bloqueios + barreira fiscal
  /// TIPADA + destino + o que seria desfeito). 403 sem CANCELAR (D-F131).
  Future<ServiceOrderCancelPlan> cancelPlan(int orderId);

  /// O efeito da voz do fisco na nota (none/apply/decide/cancel) + a dispensa
  /// vigente. 503 FISCAL_VOICE_UNAVAILABLE = efeito INDISPONÍVEL (nunca "nada
  /// pendente" — D-F130).
  Future<ServiceOrderFiscalEffect> fiscalEffect(int orderId);

  /// Cancela a nota no ERP (POST /api/billing/cancel). Com NFS-e autorizada
  /// no fisco, só DEPOIS do cancelamento no fisco (D-F28 — o fisco fala
  /// primeiro); o servidor recusa com INVOICE_CANCEL_BLOCKED se não.
  Future<ServiceOrderInvoiceCancelResult> cancel(int orderId, String reason);

  /// D-F67: "Manter a nota" — NFS-e SUBSTITUÍDA no fisco (e105102).
  Future<ServiceOrderCancelWaiverResult> cancelWaiver(int orderId, String reason);
}

class ServiceOrderInvoiceDatasourceImpl implements ServiceOrderInvoiceDatasource {
  const ServiceOrderInvoiceDatasourceImpl({required this.client});

  final ApiClient client;

  Map<String, dynamic> _data(Map<String, dynamic> json) =>
      json['data'] as Map<String, dynamic>? ?? const {};

  @override
  Future<ServiceOrderCancelPlan> cancelPlan(int orderId) async =>
      ServiceOrderCancelPlan.fromJson(_data(await client.get('/api/billing/$orderId/cancel-plan')));

  @override
  Future<ServiceOrderFiscalEffect> fiscalEffect(int orderId) async =>
      ServiceOrderFiscalEffect.fromJson(_data(await client.get('/api/billing/$orderId/fiscal-effect')));

  @override
  Future<ServiceOrderInvoiceCancelResult> cancel(int orderId, String reason) async =>
      ServiceOrderInvoiceCancelResult.fromJson(
          _data(await client.post('/api/billing/cancel', {'orderId': orderId, 'reason': reason})));

  @override
  Future<ServiceOrderCancelWaiverResult> cancelWaiver(int orderId, String reason) async =>
      ServiceOrderCancelWaiverResult.fromJson(
          _data(await client.post('/api/billing/cancel-waiver', {'orderId': orderId, 'reason': reason})));
}
