import 'package:core/core.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';

/// Datasource FISCAL da OS faturada — Onda 3 (NFS-e pelo ADN). Fala SÓ com
/// /api/billing/fiscal* e /api/billing/transmit (endpoints de PROCESSO
/// compartilhados, exceção nomeada `/api/billing/*` da ARQUITETURA_MODULOS).
/// Nunca toca /api/service-orders — a OS em si é do
/// [ServiceOrderDatasource].
abstract class ServiceOrderFiscalDatasource {
  /// Transmissões + voz do fisco + disponibilidade de XML/DANFSe.
  Future<ServiceOrderFiscalView> getView(int orderId);

  /// Transmite o DPS (201). 422 FISCAL_DPS_REJECTED traz os E0xxx em
  /// fields[]; 409 (autorizada/em progresso/emissor/certificado) e 503
  /// (fisco fora) chegam como [Failure] legível pela ponte.
  Future<ServiceOrderTransmitResult> transmit(int orderId);

  /// Consulta ativa por chave — grava a voz nova (idempotente).
  Future<ServiceOrderFiscalRefreshResult> refresh(int orderId);

  /// XML autorizado (texto).
  Future<String> xml(int orderId);

  /// DANFSe em base64 (renderização NOSSA do XML — Q-N13).
  Future<String> danfse(int orderId);

  /// Cancelamento da NFS-e no fisco + C local na mesma transação.
  Future<ServiceOrderFiscalCancelResult> cancel(int orderId, String reason);

  /// Notas faturadas SEM NFS-e (para o lote "Transmitir pendentes").
  Future<List<ServiceOrderFiscalPending>> pending();

  /// Lote de transmissão (≤ [fiscalTransmitChunkSize] por requisição).
  Future<FiscalTransmitBatchReport> transmitBatch(List<int> orderIds);
}

class ServiceOrderFiscalDatasourceImpl implements ServiceOrderFiscalDatasource {
  const ServiceOrderFiscalDatasourceImpl({required this.client});

  final ApiClient client;

  Map<String, dynamic> _data(Map<String, dynamic> json) =>
      json['data'] as Map<String, dynamic>? ?? const {};

  @override
  Future<ServiceOrderFiscalView> getView(int orderId) async {
    final json = await client.get('/api/billing/fiscal/$orderId');
    return ServiceOrderFiscalView.fromJson(_data(json));
  }

  @override
  Future<ServiceOrderTransmitResult> transmit(int orderId) async {
    final json =
        await client.post('/api/billing/transmit', {'orderId': orderId});
    return ServiceOrderTransmitResult.fromJson(_data(json));
  }

  @override
  Future<ServiceOrderFiscalRefreshResult> refresh(int orderId) async {
    final json =
        await client.post('/api/billing/fiscal/$orderId/refresh', const {});
    return ServiceOrderFiscalRefreshResult.fromJson(_data(json));
  }

  @override
  Future<String> xml(int orderId) async {
    final json = await client.get('/api/billing/fiscal/$orderId/xml');
    return _data(json)['xml']?.toString() ?? '';
  }

  @override
  Future<String> danfse(int orderId) async {
    final json = await client.get('/api/billing/fiscal/$orderId/danfse');
    return _data(json)['pdfBase64']?.toString() ?? '';
  }

  @override
  Future<ServiceOrderFiscalCancelResult> cancel(
      int orderId, String reason) async {
    final json = await client.post('/api/billing/fiscal/cancel', {
      'orderId': orderId,
      'reason': reason,
    });
    return ServiceOrderFiscalCancelResult.fromJson(_data(json));
  }

  @override
  Future<List<ServiceOrderFiscalPending>> pending() async {
    final json = await client.get('/api/billing/fiscal/pending');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) =>
            ServiceOrderFiscalPending.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FiscalTransmitBatchReport> transmitBatch(List<int> orderIds) async {
    final json = await client.post(
        '/api/billing/fiscal/transmit-batch', {'orderIds': orderIds});
    return FiscalTransmitBatchReport.fromJson(_data(json));
  }
}
