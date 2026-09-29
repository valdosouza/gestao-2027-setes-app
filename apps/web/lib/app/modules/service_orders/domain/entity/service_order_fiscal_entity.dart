import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades FISCAIS do módulo service_orders — Onda 3 (NFS-e pelo Padrão
/// Nacional, prompt_onda3_nfse_adn.md §3 B/C/E). Espelho do
/// /api/billing/fiscal/:orderId: a nota da OS faturada ganha N TRANSMISSÕES
/// do DPS (1 ramo × N tentativas — reapresentar = attempt + 1, nunca UPDATE)
/// e a VOZ DO FISCO em linha do tempo (append-only). O estado fiscal é
/// DERIVADO do último evento da última transmissão — nunca coluna.
///
/// Identidade: 1 pedido = 1 nota com o MESMO id (notas-mercadoria-servico,
/// D1) — o `invoiceId` que a API devolve é o `orderId` da OS.

/// Kinds da voz do fisco (`tb_invoice_service_transmission_event.kind`) —
/// NOSSA leitura da resposta, nunca o código cru (que vai em authorityCode).
abstract final class FiscalTransmissionKind {
  /// Enviado (DPS recebido, sem desfecho ainda).
  static const sent = 'S';

  /// Autorizada (NFS-e resultou: chave 50, número, protocolo).
  static const authorized = 'A';

  /// Rejeitada (DPS recusado pelo fisco — nova tentativa = attempt + 1).
  static const rejected = 'R';

  /// Cancelada (evento de cancelamento aceito pelo fisco).
  static const cancelled = 'C';

  /// Cancelamento EM VOO (pedido ambíguo — bloqueia até reconciliar).
  static const cancelInFlight = 'K';

  /// Falha explícita (transporte/assinatura — sem voz do fisco).
  static const failed = 'F';

  /// Kinds que ENCERRAM a transmissão — a partir deles cabe nova tentativa.
  static const finals = {rejected, cancelled, failed};
}

/// Uma transmissão do DPS ao ADN (espelho de
/// tb_invoice_service_transmission). Campos write-once chegam na
/// autorização/consulta e nunca mudam; [lastKind]/[lastCode]/[lastMessage]/
/// [lastDh] resumem o ÚLTIMO evento desta tentativa.
class ServiceOrderFiscalTransmission extends Equatable {
  const ServiceOrderFiscalTransmission({
    required this.attempt,
    this.environment = 'H',
    this.dpsId,
    this.accessKey,
    this.nfseNumber,
    this.dhProc,
    this.createdAt,
    this.lastQueriedAt,
    this.lastKind,
    this.lastCode,
    this.lastMessage,
    this.lastDh,
  });

  final int     attempt;

  /// 'H' produção restrita (homologação) · 'P' produção — CONGELADO.
  final String  environment;
  final String? dpsId;

  /// Chave de acesso da NFS-e (50 posições) — write-once na autorização.
  final String? accessKey;
  final String? nfseNumber;

  /// Data/hora do processamento no fisco (ISO).
  final String? dhProc;
  final String? createdAt;

  /// D-I20 (Onda 2): o fato "nós olhamos o fisco" — write-many.
  final String? lastQueriedAt;
  final String? lastKind;
  final String? lastCode;
  final String? lastMessage;
  final String? lastDh;

  /// Vigente = último evento NÃO final (ou envio em andamento). Enquanto
  /// há transmissão vigente a API recusa nova (409 FISCAL_ALREADY_AUTHORIZED /
  /// FISCAL_TRANSMISSION_IN_PROGRESS) — a tela esconde o Transmitir.
  bool get isLive =>
      !FiscalTransmissionKind.finals.contains(lastKind ?? '');

  bool get isAuthorized => lastKind == FiscalTransmissionKind.authorized;

  bool get cancelInFlight => lastKind == FiscalTransmissionKind.cancelInFlight;

  /// Enviado mas sem DPS registrado nem resposta (envio interrompido).
  bool get inFlight => dpsId == null && lastKind == null;

  factory ServiceOrderFiscalTransmission.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalTransmission(
        attempt:       jsonInt(json['attempt']) ?? 0,
        environment:   json['environment'] as String? ?? 'H',
        dpsId:         json['dpsId']?.toString(),
        accessKey:     json['accessKey']?.toString(),
        nfseNumber:    json['nfseNumber']?.toString(),
        dhProc:        json['dhProc']?.toString(),
        createdAt:     json['createdAt']?.toString(),
        lastQueriedAt: json['lastQueriedAt']?.toString(),
        lastKind:      json['lastKind'] as String?,
        lastCode:      json['lastCode']?.toString(),
        lastMessage:   json['lastMessage'] as String?,
        lastDh:        json['lastDh']?.toString(),
      );

  @override
  List<Object?> get props => [
        attempt, environment, dpsId, accessKey, nfseNumber, dhProc, createdAt,
        lastQueriedAt, lastKind, lastCode, lastMessage, lastDh,
      ];
}

/// Uma fala do fisco sobre uma transmissão (append-only — espelho de
/// tb_invoice_service_transmission_event). [invoiceEvent] liga a causa ao
/// EFEITO na nota (evento C de tb_invoice_event); voz com efeito (C) sem
/// invoiceEvent = efeito recusado pelas nossas regras — pendência (D-I10).
class ServiceOrderFiscalEvent extends Equatable {
  const ServiceOrderFiscalEvent({
    required this.attempt,
    required this.event,
    required this.kind,
    this.authorityCode,
    this.message,
    this.dh,
    this.source,
    this.invoiceEvent,
    this.createdAt,
  });

  final int     attempt;
  final int     event;
  final String  kind;

  /// Código CRU do fisco (E0xxx...).
  final String? authorityCode;
  final String? message;
  final String? dh;

  /// 'P' resposta direta ao nosso pedido · 'Q' consulta.
  final String? source;
  final int?    invoiceEvent;
  final String? createdAt;

  factory ServiceOrderFiscalEvent.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalEvent(
        attempt:       jsonInt(json['attempt']) ?? 0,
        event:         jsonInt(json['event']) ?? 0,
        kind:          json['kind'] as String? ?? '',
        authorityCode: json['authorityCode']?.toString(),
        message:       json['message'] as String?,
        dh:            json['dh']?.toString(),
        source:        json['source'] as String?,
        invoiceEvent:  jsonInt(json['invoiceEvent']),
        createdAt:     json['createdAt']?.toString(),
      );

  @override
  List<Object?> get props => [
        attempt, event, kind, authorityCode, message, dh, source,
        invoiceEvent, createdAt,
      ];
}

/// Visão fiscal da nota da OS (GET /api/billing/fiscal/:orderId).
class ServiceOrderFiscalView extends Equatable {
  const ServiceOrderFiscalView({
    this.transmissions = const [],
    this.events = const [],
    this.pendingEffects = 0,
    this.xmlAvailable = false,
    this.danfseAvailable = false,
  });

  /// Transmissões em ordem de tentativa (a última é a que a tela mostra).
  final List<ServiceOrderFiscalTransmission> transmissions;

  /// Voz do fisco em ordem cronológica.
  final List<ServiceOrderFiscalEvent> events;

  /// Falas do fisco com efeito RECUSADO aqui (D-I10) — pendência visível.
  final int  pendingEffects;
  final bool xmlAvailable;
  final bool danfseAvailable;

  /// Última transmissão (a vigente ou a última encerrada); null = nunca
  /// transmitida.
  ServiceOrderFiscalTransmission? get lastTransmission =>
      transmissions.isEmpty ? null : transmissions.last;

  /// Há transmissão VIGENTE (esconde o Transmitir).
  bool get hasLiveTransmission => lastTransmission?.isLive ?? false;

  /// NFS-e AUTORIZADA vigente — habilita "Cancelar NFS-e" e esconde o
  /// "Cancelar nota" local (a API recusaria com FISCAL_CANCEL_REQUIRED).
  bool get isAuthorized => lastTransmission?.isAuthorized ?? false;

  /// Cancelamento em voo (K): nada pode ser feito até a consulta reconciliar.
  bool get cancelInFlight => lastTransmission?.cancelInFlight ?? false;

  /// O cancelamento LOCAL ("Cancelar nota") fica bloqueado enquanto o fisco
  /// tem a última palavra: nota autorizada ou cancelamento em voo.
  bool get blocksLocalCancel => isAuthorized || cancelInFlight;

  bool get hasPendingEffects => pendingEffects > 0;

  factory ServiceOrderFiscalView.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalView(
        transmissions: (json['transmissions'] as List<dynamic>? ?? [])
            .map((e) => ServiceOrderFiscalTransmission.fromJson(
                e as Map<String, dynamic>))
            .toList(),
        events: (json['events'] as List<dynamic>? ?? [])
            .map((e) =>
                ServiceOrderFiscalEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        pendingEffects:  jsonInt(json['pendingEffects']) ?? 0,
        xmlAvailable:    json['xmlAvailable'] == true,
        danfseAvailable: json['danfseAvailable'] == true,
      );

  @override
  List<Object?> get props =>
      [transmissions, events, pendingEffects, xmlAvailable, danfseAvailable];
}

/// Resultado do Transmitir (POST /api/billing/transmit — 201).
class ServiceOrderTransmitResult extends Equatable {
  const ServiceOrderTransmitResult({
    required this.invoiceId,
    this.attempt = 0,
    this.dpsId,
    this.accessKey,
    this.kind,
  });

  final int     invoiceId;
  final int     attempt;
  final String? dpsId;
  final String? accessKey;

  /// Kind da voz que fechou a transmissão (S/A) — R vem como 422.
  final String? kind;

  bool get authorized => kind == FiscalTransmissionKind.authorized;

  factory ServiceOrderTransmitResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderTransmitResult(
        invoiceId: jsonInt(json['invoiceId']) ?? 0,
        attempt:   jsonInt(json['attempt']) ?? 0,
        dpsId:     json['dpsId']?.toString(),
        accessKey: json['accessKey']?.toString(),
        kind:      json['kind'] as String?,
      );

  @override
  List<Object?> get props => [invoiceId, attempt, dpsId, accessKey, kind];
}

/// Resultado do Consultar (POST /api/billing/fiscal/:orderId/refresh).
class ServiceOrderFiscalRefreshResult extends Equatable {
  const ServiceOrderFiscalRefreshResult({
    this.changed = false,
    this.kind,
    this.accessKey,
  });

  /// true = a consulta trouxe voz nova (a linha do tempo mudou).
  final bool    changed;
  final String? kind;
  final String? accessKey;

  bool get authorized => kind == FiscalTransmissionKind.authorized;

  factory ServiceOrderFiscalRefreshResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalRefreshResult(
        changed:   json['changed'] == true,
        kind:      json['kind'] as String?,
        accessKey: json['accessKey']?.toString(),
      );

  @override
  List<Object?> get props => [changed, kind, accessKey];
}

/// Resultado do Cancelar NFS-e (POST /api/billing/fiscal/cancel): 'C' =
/// fisco aceitou e a nota local também cancelou (a OS volta a aberta); 'K' =
/// pedido em voo (503 do fisco — consulta reconcilia). [warnings] são avisos
/// não bloqueantes que a tela mostra pela ponte.
class ServiceOrderFiscalCancelResult extends Equatable {
  const ServiceOrderFiscalCancelResult({
    required this.invoiceId,
    this.kind = FiscalTransmissionKind.cancelled,
    this.warnings = const [],
  });

  final int          invoiceId;
  final String       kind;
  final List<String> warnings;

  bool get cancelled => kind == FiscalTransmissionKind.cancelled;
  bool get inFlight => kind == FiscalTransmissionKind.cancelInFlight;

  factory ServiceOrderFiscalCancelResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalCancelResult(
        invoiceId: jsonInt(json['invoiceId']) ?? 0,
        kind:      json['kind'] as String? ?? FiscalTransmissionKind.cancelled,
        warnings:  (json['warnings'] as List<dynamic>? ?? [])
            .map((w) => w.toString())
            .where((w) => w.isNotEmpty)
            .toList(),
      );

  @override
  List<Object?> get props => [invoiceId, kind, warnings];
}

/// Nota da OS faturada SEM NFS-e (GET /api/billing/fiscal/pending). Como
/// 1 pedido = 1 nota com o MESMO id, [invoiceId] é o orderId que o lote
/// transmite.
class ServiceOrderFiscalPending extends Equatable {
  const ServiceOrderFiscalPending({
    required this.invoiceId,
    this.number,
    this.dtEmission,
  });

  final int     invoiceId;
  final String? number;
  final String? dtEmission;

  /// Identidade compartilhada nota × pedido (D1 de notas-mercadoria-serviço).
  int get orderId => invoiceId;

  factory ServiceOrderFiscalPending.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalPending(
        invoiceId:  jsonInt(json['invoiceId']) ?? 0,
        number:     json['number']?.toString(),
        dtEmission: json['dtEmission']?.toString(),
      );

  @override
  List<Object?> get props => [invoiceId, number, dtEmission];
}

/// Uma linha do relatório do lote de transmissão (POST /transmit-batch):
/// o resultado REAL de cada ordem — recusada traz código/mensagem do fisco
/// ou da nossa regra.
class FiscalTransmitBatchRow extends Equatable {
  const FiscalTransmitBatchRow({
    required this.orderId,
    required this.ok,
    this.kind,
    this.code = '',
    this.message = '',
  });

  /// Linha que a TELA fabrica quando um bloco nem chegou à API (D27 do lote
  /// de faturamento: bloco que falha inteiro depois de outro já ter rodado
  /// não pode apagar o relatório do que já foi transmitido).
  const FiscalTransmitBatchRow.aborted(
      {required this.orderId, required this.message})
      : ok = false,
        kind = null,
        code = abortedCode;

  static const abortedCode = 'BATCH_ABORTED';

  final int     orderId;
  final bool    ok;
  final String? kind;
  final String  code;
  final String  message;

  factory FiscalTransmitBatchRow.fromJson(Map<String, dynamic> json) =>
      FiscalTransmitBatchRow(
        orderId: jsonInt(json['orderId']) ?? 0,
        ok:      json['ok'] == true,
        kind:    json['kind'] as String?,
        code:    json['code']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [orderId, ok, kind, code, message];
}

/// Teto de ordens por REQUISIÇÃO no /transmit-batch (contrato da API). A
/// tela fatia em blocos deste tamanho e agrega ([FiscalTransmitBatchReport.merge]).
const int fiscalTransmitChunkSize = 50;

/// Relatório do lote de transmissão — a API responde 200 mesmo com recusas
/// parciais; os contadores são SEMPRE recontados das linhas.
class FiscalTransmitBatchReport extends Equatable {
  const FiscalTransmitBatchReport({
    this.transmitted = 0,
    this.refused = 0,
    this.rows = const [],
  });

  final int transmitted;
  final int refused;
  final List<FiscalTransmitBatchRow> rows;

  int get requested => rows.length;

  List<FiscalTransmitBatchRow> get refusedRows =>
      rows.where((r) => !r.ok).toList();

  factory FiscalTransmitBatchReport.fromJson(Map<String, dynamic> json) =>
      FiscalTransmitBatchReport.fromEntries(
        (json['rows'] as List<dynamic>? ?? [])
            .map((e) =>
                FiscalTransmitBatchRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory FiscalTransmitBatchReport.fromEntries(
          List<FiscalTransmitBatchRow> rows) =>
      FiscalTransmitBatchReport(
        transmitted: rows.where((r) => r.ok).length,
        refused:     rows.where((r) => !r.ok).length,
        rows:        List.unmodifiable(rows),
      );

  /// Agrega os relatórios dos blocos na ORDEM em que rodaram.
  static FiscalTransmitBatchReport merge(
          Iterable<FiscalTransmitBatchReport> parts) =>
      FiscalTransmitBatchReport.fromEntries(
          [for (final p in parts) ...p.rows]);

  @override
  List<Object?> get props => [transmitted, refused, rows];
}
