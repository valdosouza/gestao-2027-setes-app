import 'package:core/core.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';

/// Datasource da NFS-e da OS faturada — fala SÓ com a nfse-api (D-F4/D-F139,
/// F2b): `GET/POST /v1/nfse/invoices/{id}…` e as notas sem NFS-e. Recebe o
/// [NfseApiClient] (base `NFSE_API_URL`, o MESMO token do login — D-F138);
/// nunca toca o setes-api — o efeito na nota e o plano são do
/// [ServiceOrderInvoiceDatasource].
///
/// Identidade: o `invoiceId` da nfse-api é o `orderId` da OS (D1).
abstract class ServiceOrderNfseDatasource {
  /// A voz do fisco sobre a nota (estado, tentativa vigente, linha do tempo).
  Future<ServiceOrderFiscalView> getView(int invoiceId);

  /// Transmite o DPS (201 só com autorizada). 422 FISCAL_DPS_REJECTED traz os
  /// E0xxx em fields[]; 502/503 = desfecho DESCONHECIDO (a tentativa pode
  /// estar em voo — releia e consulte).
  Future<ServiceOrderTransmitResult> transmit(int invoiceId);

  /// Consulta ativa (grava a voz nova — idempotente).
  Future<ServiceOrderFiscalRefreshResult> refresh(int invoiceId);

  /// Reconferência (D-F109): pergunta ao fisco se a NFS-e do envio
  /// interrompido existe; quem decide o cancelamento é o PLANO relido.
  Future<ServiceOrderFiscalReconfirmResult> reconfirm(int invoiceId);

  /// Cancela a NFS-e NO FISCO; o efeito na nota é o passo seguinte no ERP.
  Future<ServiceOrderFiscalCancelResult> cancel(int invoiceId, String reason);

  Future<String> xml(int invoiceId);

  /// DANFSe em base64.
  Future<String> danfse(int invoiceId);

  /// Uma página das notas da OS sem NFS-e (D-F145: o filtro do ramo é do
  /// SERVIDOR — `interfaceKey=service-orders`).
  Future<PagedResult<ServiceOrderFiscalPending>> pending({int page = 1, int pageSize = 100});
}

class ServiceOrderNfseDatasourceImpl implements ServiceOrderNfseDatasource {
  const ServiceOrderNfseDatasourceImpl({required this.client});

  final NfseApiClient client;

  static const _base = '/v1/nfse/invoices';

  /// F2B-ADV-04: `{ ok: true, data: {…} }` ou falha técnica — nunca `{}` virando
  /// "não transmitida"/"autorizada".
  Map<String, dynamic> _data(Map<String, dynamic> json) => envelopeData(json, service: 'nfse-api');

  @override
  Future<ServiceOrderFiscalView> getView(int invoiceId) async =>
      ServiceOrderFiscalView.fromJson(_data(await client.get('$_base/$invoiceId')));

  @override
  Future<ServiceOrderTransmitResult> transmit(int invoiceId) async =>
      ServiceOrderTransmitResult.fromJson(
          _data(await client.post('$_base/$invoiceId/transmit', const {})));

  @override
  Future<ServiceOrderFiscalRefreshResult> refresh(int invoiceId) async =>
      ServiceOrderFiscalRefreshResult.fromJson(
          _data(await client.post('$_base/$invoiceId/refresh', const {})));

  @override
  Future<ServiceOrderFiscalReconfirmResult> reconfirm(int invoiceId) async =>
      ServiceOrderFiscalReconfirmResult.fromJson(
          _data(await client.post('$_base/$invoiceId/reconfirm', const {})));

  @override
  Future<ServiceOrderFiscalCancelResult> cancel(int invoiceId, String reason) async =>
      ServiceOrderFiscalCancelResult.fromJson(
          _data(await client.post('$_base/$invoiceId/cancel', {'reason': reason})));

  @override
  Future<String> xml(int invoiceId) async =>
      _data(await client.get('$_base/$invoiceId/xml'))['xml']?.toString() ?? '';

  @override
  Future<String> danfse(int invoiceId) async =>
      _data(await client.get('$_base/$invoiceId/danfse'))['pdfBase64']?.toString() ?? '';

  @override
  Future<PagedResult<ServiceOrderFiscalPending>> pending({int page = 1, int pageSize = 100}) async {
    final json = await client.get('$_base/pending?interfaceKey=service-orders&page=$page&pageSize=$pageSize');
    return PagedResult.fromJson(envelopePage(json, service: 'nfse-api'), ServiceOrderFiscalPending.fromJson);
  }
}
