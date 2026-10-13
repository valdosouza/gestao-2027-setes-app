import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades FISCAIS do módulo service_orders — F2b (o app é cliente DIRETO
/// da nfse-api — D-F4; `prompt_apis_fiscais_isoladas.md` §22.14/§22.16).
///
/// DUAS fontes, DUAS falhas (D-F139, parecer do guardião): a VOZ do fisco vem
/// da nfse-api (`GET /v1/nfse/invoices/{id}` → [ServiceOrderFiscalView]); o
/// EFEITO dela na nota e o PLANO de cancelamento vêm do ERP (setes-api —
/// `GET /api/billing/:orderId/fiscal-effect` → [ServiceOrderFiscalEffect],
/// `GET /api/billing/:orderId/cancel-plan` → [ServiceOrderCancelPlan]).
///
/// O app NUNCA decide fato fiscal (D-F142): nada aqui deriva "autorizada",
/// "viva", "registro fiscal" ou "pode cancelar" de colunas — o estado vem do
/// servidor (`state`, `currentAttempt`, `effect`, a barreira do plano); o kind
/// é só RÓTULO na linha do tempo.
///
/// Identidade: 1 pedido = 1 nota com o MESMO id (notas-mercadoria-servico,
/// D1) — o `invoiceId` da nfse-api é o `orderId` da OS.

/// Kinds da voz do fisco — só para RÓTULO (D-F142). N = o cancelamento NÃO
/// aconteceu e a NFS-e segue autorizada (D-N17).
abstract final class FiscalTransmissionKind {
  static const sent = 'S';
  static const authorized = 'A';
  static const rejected = 'R';
  static const cancelled = 'C';
  static const cancelInFlight = 'K';
  static const failed = 'F';
  static const notCancelled = 'N';
}

/// Estado da NFS-e (o `state` DERIVADO pelo núcleo — `fiscalStateOf`). Valor
/// fora desta lista (API mais nova que o build) = desconhecido: neutro, sem
/// ação.
abstract final class NfseState {
  static const none = 'none';
  static const inFlight = 'in_flight';
  static const processing = 'processing';
  static const authorized = 'authorized';
  static const denied = 'denied';
  static const rejected = 'rejected';
  static const failed = 'failed';
  static const cancelled = 'cancelled';
  static const cancelInFlight = 'cancel_in_flight';

  /// D-F130 (selo da LISTA de OS): a voz do fisco ilegível agora no ERP.
  static const unavailable = 'unavailable';

  /// Só do APP: a resposta não trouxe o `state` (F2B-SOC-06 — ausência nunca
  /// é "nunca transmitida"): neutro, sem ação.
  static const unknown = 'unknown';

  /// Estados em que cabe transmitir (de novo): nunca transmitida, ou a última
  /// tentativa fechou sem NFS-e (R/F). O servidor reconfere (409).
  static const transmittable = {none, rejected, failed};
}

/// Uma tentativa ao fisco (linha de `transmissions` da nfse-api). Os campos
/// do último evento resumem a tentativa — só para EXIBIÇÃO.
class ServiceOrderFiscalTransmission extends Equatable {
  const ServiceOrderFiscalTransmission({
    required this.attempt,
    this.environment,
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

  final int attempt;

  /// 'H' produção restrita (homologação) · 'P' produção — só rótulo.
  final String? environment;
  final String? dpsId;
  final String? accessKey;
  final String? nfseNumber;
  final String? dhProc;
  final String? createdAt;
  final String? lastQueriedAt;
  final String? lastKind;
  final String? lastCode;
  final String? lastMessage;
  final String? lastDh;

  factory ServiceOrderFiscalTransmission.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalTransmission(
        attempt:       jsonInt(json['attempt']) ?? 0,
        environment:   json['environment'] as String?,
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

/// Uma fala do fisco (linha de `events` da nfse-api) — append-only.
class ServiceOrderFiscalEvent extends Equatable {
  const ServiceOrderFiscalEvent({
    required this.attempt,
    required this.event,
    required this.kind,
    this.authorityCode,
    this.message,
    this.dh,
    this.source,
    this.createdAt,
  });

  final int attempt;
  final int event;
  final String kind;

  /// Código CRU do fisco (E0xxx, tpEvento do cancelamento…).
  final String? authorityCode;
  final String? message;

  /// Instante da VOZ do fisco (null nos fatos nossos — K da reserva, N).
  final String? dh;

  /// 'P' resposta direta · 'Q' consulta.
  final String? source;
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
        createdAt:     json['createdAt']?.toString(),
      );

  @override
  List<Object?> get props =>
      [attempt, event, kind, authorityCode, message, dh, source, createdAt];
}

/// D-F67/D-F76: a NFS-e vigente foi cancelada por SUBSTITUIÇÃO no fisco
/// (e105102) — existe uma SUBSTITUTA que o ERP não conhece. A decisão humana
/// (manter × cancelar) é do ERP: vem em [ServiceOrderFiscalEffect].
class ServiceOrderFiscalSubstitution extends Equatable {
  const ServiceOrderFiscalSubstitution({this.substituteAccessKey});

  /// Chave da SUBSTITUTA — null = XML do evento indisponível (a tela diz
  /// "indisponível", nunca inventa).
  final String? substituteAccessKey;

  bool get hasSubstituteKey =>
      substituteAccessKey != null && substituteAccessKey!.isNotEmpty;

  factory ServiceOrderFiscalSubstitution.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalSubstitution(
          substituteAccessKey: json['substituteAccessKey']?.toString());

  @override
  List<Object?> get props => [substituteAccessKey];
}

T? _optionalBlock<T>(
        Object? raw, T Function(Map<String, dynamic> json) fromJson) =>
    raw is Map<String, dynamic> ? fromJson(raw) : null;

/// A VOZ do fisco sobre a nota (nfse-api — `GET /v1/nfse/invoices/{id}`).
class ServiceOrderFiscalView extends Equatable {
  const ServiceOrderFiscalView({
    this.state = NfseState.none,
    this.currentAttempt,
    this.transmissions = const [],
    this.events = const [],
    this.localCancelPending = false,
    this.substitution,
    this.xmlAvailable = false,
    this.danfseAvailable = false,
  });

  /// Estado derivado pelo núcleo (D-F142) — a tela escolhe os botões por ele.
  final String state;

  /// D-F142: a tentativa VIGENTE (`currentOf` do núcleo — a registrada pelo
  /// fisco, senão a última). null = nunca transmitida nesta vida.
  final int? currentAttempt;
  final List<ServiceOrderFiscalTransmission> transmissions;
  final List<ServiceOrderFiscalEvent> events;

  /// Voz C do fisco sem o C local (a nfse-api diz; o ERP dá o efeito exato).
  final bool localCancelPending;
  final ServiceOrderFiscalSubstitution? substitution;
  final bool xmlAvailable;
  final bool danfseAvailable;

  /// A tentativa vigente — pelo número que o SERVIDOR escolheu (nunca
  /// `transmissions.last`: a registrada pode não ser a última).
  ServiceOrderFiscalTransmission? get current {
    for (final t in transmissions) {
      if (t.attempt == currentAttempt) return t;
    }
    return null;
  }

  bool get isSubstituted => substitution != null;

  bool get canTransmitState => NfseState.transmittable.contains(state);

  factory ServiceOrderFiscalView.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalView(
        state:          json['state'] is String ? json['state'] as String : NfseState.unknown,
        currentAttempt: jsonInt(json['currentAttempt']),
        transmissions: (json['transmissions'] as List<dynamic>? ?? [])
            .map((e) => ServiceOrderFiscalTransmission.fromJson(
                e as Map<String, dynamic>))
            .toList(),
        events: (json['events'] as List<dynamic>? ?? [])
            .map((e) =>
                ServiceOrderFiscalEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        localCancelPending: json['localCancelPending'] == true,
        substitution: _optionalBlock(
            json['substitution'], ServiceOrderFiscalSubstitution.fromJson),
        xmlAvailable:    json['xmlAvailable'] == true,
        danfseAvailable: json['danfseAvailable'] == true,
      );

  @override
  List<Object?> get props => [
        state, currentAttempt, transmissions, events, localCancelPending,
        substitution, xmlAvailable, danfseAvailable,
      ];
}

/// D-F114: o EFEITO da voz do fisco na nota — classificação do ERP.
enum FiscalEffect {
  /// Nada a fazer.
  none,

  /// O fisco cancelou — falta aplicar o cancelamento na nota (D-F140: o humano
  /// confirma pelo plano; o app nunca aplica sozinho).
  apply,

  /// NFS-e SUBSTITUÍDA no fisco (produção) — o humano decide: manter × cancelar.
  decide,

  /// O fisco cancelou (de ofício, ou substituição em homologação) — cancele a nota.
  cancel,

  /// Valor que este build não conhece (API mais nova) — neutro, sem ação.
  unknown;

  static FiscalEffect parse(Object? raw) => switch (raw) {
        'none' => FiscalEffect.none,
        'apply' => FiscalEffect.apply,
        'decide' => FiscalEffect.decide,
        'cancel' => FiscalEffect.cancel,
        _ => FiscalEffect.unknown,
      };
}

/// D-F67/D-F81: a decisão humana de MANTER a nota (quem, quando e por quê).
class ServiceOrderFiscalCancelWaiver extends Equatable {
  const ServiceOrderFiscalCancelWaiver({
    required this.accessKey,
    required this.reason,
    this.userId,
    this.createdAt,
  });

  final String accessKey;
  final String reason;
  final int? userId;
  final String? createdAt;

  factory ServiceOrderFiscalCancelWaiver.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalCancelWaiver(
        accessKey: json['accessKey']?.toString() ?? '',
        reason:    json['reason']?.toString() ?? '',
        userId:    jsonInt(json['userId']),
        createdAt: json['createdAt']?.toString(),
      );

  @override
  List<Object?> get props => [accessKey, reason, userId, createdAt];
}

/// O EFEITO na nota (ERP — `GET /api/billing/:orderId/fiscal-effect`).
class ServiceOrderFiscalEffect extends Equatable {
  const ServiceOrderFiscalEffect({
    this.effect = FiscalEffect.none,
    this.invoiceCancelled = false,
    this.cancelWaiver,
  });

  final FiscalEffect effect;
  final bool invoiceCancelled;

  /// A decisão "manter a nota" VIGENTE — null = não há.
  final ServiceOrderFiscalCancelWaiver? cancelWaiver;

  factory ServiceOrderFiscalEffect.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalEffect(
        effect:           FiscalEffect.parse(json['effect']),
        invoiceCancelled: json['invoiceCancelled'] == true,
        cancelWaiver: _optionalBlock(
            json['cancelWaiver'], ServiceOrderFiscalCancelWaiver.fromJson),
      );

  @override
  List<Object?> get props => [effect, invoiceCancelled, cancelWaiver];
}

/// D-F141: a barreira fiscal TIPADA do plano — a AÇÃO que a tela oferece.
enum FiscalBarrierKind {
  /// NFS-e autorizada no fisco (produção) — cancele a NFS-e no fisco primeiro.
  authorized,

  /// Transmissão em andamento — aguarde a voz do fisco.
  inFlight,

  /// Pedido de cancelamento sem resposta — consulte a NFS-e no fisco.
  cancelInFlight,

  /// Envio interrompido sem prova de que a NFS-e não existe — reconfira.
  reconfirm,

  /// Valor que este build não conhece — mostra a mensagem, sem ação.
  unknown;

  static FiscalBarrierKind parse(Object? raw) => switch (raw) {
        'authorized' => FiscalBarrierKind.authorized,
        'in-flight' => FiscalBarrierKind.inFlight,
        'cancel-in-flight' => FiscalBarrierKind.cancelInFlight,
        'reconfirm' => FiscalBarrierKind.reconfirm,
        _ => FiscalBarrierKind.unknown,
      };
}

class FiscalBarrier extends Equatable {
  const FiscalBarrier({required this.kind, this.reason, this.attempt});

  final FiscalBarrierKind kind;

  /// Motivo do veredito da reconferência (só em [FiscalBarrierKind.reconfirm]).
  final String? reason;
  final int? attempt;

  factory FiscalBarrier.fromJson(Map<String, dynamic> json) => FiscalBarrier(
        kind:    FiscalBarrierKind.parse(json['kind']),
        reason:  json['reason']?.toString(),
        attempt: jsonInt(json['attempt']),
      );

  @override
  List<Object?> get props => [kind, reason, attempt];
}

/// Um bloqueio do plano (título baixado, boleto, cheque, devolução, OS do
/// cliente aberta, fisco) — a mensagem é a do servidor.
class CancelPlanBlock extends Equatable {
  const CancelPlanBlock({
    required this.field,
    required this.message,
    this.ref = '',
    this.barrier,
  });

  final String field;
  final String message;
  final String ref;

  /// Só no bloco `fiscal` (D-F141).
  final FiscalBarrier? barrier;

  factory CancelPlanBlock.fromJson(Map<String, dynamic> json) =>
      CancelPlanBlock(
        field:   json['field']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        ref:     json['ref']?.toString() ?? '',
        barrier: _optionalBlock(json['barrier'], FiscalBarrier.fromJson),
      );

  @override
  List<Object?> get props => [field, message, ref, barrier];
}

/// O PLANO de cancelamento (ERP — `GET /api/billing/:orderId/cancel-plan`):
/// o MESMO cálculo do POST (D-F128). A tela decide o próximo passo só por
/// ele: cancelável → motivo → cancelar; só a barreira `authorized` → cancelar
/// a NFS-e no fisco e depois a nota; `reconfirm` → reconferir; o resto →
/// mostrar os bloqueios.
class ServiceOrderCancelPlan extends Equatable {
  const ServiceOrderCancelPlan({
    required this.orderId,
    this.invoiceNumber,
    this.cancellable = false,
    this.blocks = const [],
    this.fiscalRecord = false,
    this.touchesCash = false,
    this.cashierOpen,
  });

  final int orderId;
  final String? invoiceNumber;
  final bool cancellable;
  final List<CancelPlanBlock> blocks;

  /// D3/D4: com registro fiscal a nota FICA (evento C) e o pedido vira 'C'.
  final bool fiscalRecord;
  final bool touchesCash;

  /// D16 do operador (F2A3-SOC-12): null quando o cancelamento não toca o caixa.
  final bool? cashierOpen;

  /// A barreira fiscal do plano (null = o fisco não barra). Bloco `fiscal` SEM
  /// barreira tipada = barreira DESCONHECIDA (F2B-ADV-09 — nunca "o fisco não
  /// barra"): a tela mostra a mensagem e não oferece ação.
  FiscalBarrier? get fiscalBarrier {
    for (final b in blocks) {
      if (b.field == 'fiscal') return b.barrier ?? const FiscalBarrier(kind: FiscalBarrierKind.unknown);
    }
    return null;
  }

  /// O mesmo plano com o id da OS que a TELA pediu (F2B-ADV-09: resposta sem
  /// `orderId` virava 0 e a saga iria para a nota 0).
  ServiceOrderCancelPlan withOrderId(int id) => ServiceOrderCancelPlan(
        orderId: id, invoiceNumber: invoiceNumber, cancellable: cancellable, blocks: blocks,
        fiscalRecord: fiscalRecord, touchesCash: touchesCash, cashierOpen: cashierOpen,
      );

  /// Bloqueios que NÃO são do fisco (título, boleto, cheque…).
  List<CancelPlanBlock> get localBlocks =>
      blocks.where((b) => b.field != 'fiscal').toList();

  /// O único impedimento é a NFS-e autorizada no fisco (e o caixa, se tocar,
  /// está aberto): cancelar no fisco e depois a nota é seguro — o local não
  /// vai recusar por outro motivo (R-B4).
  bool get onlyAuthorityStands =>
      localBlocks.isEmpty &&
      fiscalBarrier?.kind == FiscalBarrierKind.authorized &&
      cashierOpen != false;

  factory ServiceOrderCancelPlan.fromJson(Map<String, dynamic> json) {
    final effects = json['effects'] as Map<String, dynamic>? ?? const {};
    return ServiceOrderCancelPlan(
      orderId:       jsonInt(json['orderId']) ?? 0,
      invoiceNumber: json['invoiceNumber']?.toString(),
      cancellable:   json['cancellable'] == true,
      blocks: (json['blocks'] as List<dynamic>? ?? [])
          .map((e) => CancelPlanBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      fiscalRecord: json['fiscalRecord'] == true,
      touchesCash:  effects['touchesCash'] == true,
      cashierOpen:  effects['cashierOpen'] is bool ? effects['cashierOpen'] as bool : null,
    );
  }

  @override
  List<Object?> get props => [
        orderId, invoiceNumber, cancellable, blocks, fiscalRecord, touchesCash,
        cashierOpen,
      ];
}

/// Resultado do "Manter a nota" (POST /api/billing/cancel-waiver — D-F67).
class ServiceOrderCancelWaiverResult extends Equatable {
  const ServiceOrderCancelWaiverResult({
    required this.orderId,
    this.accessKey,
    this.createdAt,
    this.alreadyWaived = false,
  });

  final int orderId;
  final String? accessKey;
  final String? createdAt;
  final bool alreadyWaived;

  factory ServiceOrderCancelWaiverResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderCancelWaiverResult(
        orderId:       jsonInt(json['orderId']) ?? 0,
        accessKey:     json['accessKey']?.toString(),
        createdAt:     json['createdAt']?.toString(),
        alreadyWaived: json['alreadyWaived'] == true,
      );

  @override
  List<Object?> get props => [orderId, accessKey, createdAt, alreadyWaived];
}

/// Códigos que MUDAM o comportamento da tela (D-F144); o resto passa a
/// mensagem da API pela ponte.
abstract final class FiscalCodes {
  static const cancelWaiverNotApplicable = 'INVOICE_CANCEL_WAIVER_NOT_APPLICABLE';
  static const invoiceCancelBlocked = 'INVOICE_CANCEL_BLOCKED';
  static const invoiceNotCancellable = 'INVOICE_NOT_CANCELLABLE';
  static const dpsRejected = 'FISCAL_DPS_REJECTED';
  static const authorityUnknown = 'FISCAL_AUTHORITY_UNKNOWN_RESPONSE';
  static const authorityUnavailable = 'FISCAL_AUTHORITY_UNAVAILABLE';
  static const resourceBusy = 'RESOURCE_BUSY';
  static const cutoverPending = 'FISCAL_CUTOVER_PENDING';
  static const voiceUnavailable = 'FISCAL_VOICE_UNAVAILABLE';

  /// Só do APP (D-F149): o plano relido antes do fisco não é mais "só a NFS-e
  /// autorizada impede" — a saga não vai ao fisco.
  static const cancelPlanChanged = 'CANCEL_PLAN_CHANGED';
}

/// Desfecho DESCONHECIDO de um ato no fisco (D-F139: nunca "não aconteceu"):
/// resposta ambígua (502), fisco fora (503) ou a rede caiu no meio — a
/// tentativa pode estar em voo; a tela RELÊ e oferece "Consultar".
///
/// Gate adversarial da F2b (F2B-ADV-01/ADV-04/ADV-12): também o 408/502/503/504
/// SEM código da casa (o gateway — nginx/Plesk — desistiu antes da nfse-api, que
/// pode estar com a tentativa em voo) e a resposta 2xx que não é o envelope ou
/// não se lê (a resposta não diz o que aconteceu). D-F155 (= Q-F163 (a), Valdo
/// 2026-10-13): o 500 da nfse-api (`INTERNAL` ou sem código) também — ela pode
/// ter falhado DEPOIS de falar com o fisco. D-F163 (= Q-F171 (a), Valdo
/// 2026-10-13 — gate adversarial da Rodada 5): o 409 `RESOURCE_BUSY` também — a
/// nfse-api o devolve quando a gravação da voz DEPOIS do fisco esbarra numa
/// trava (a NFS-e pode ter sido autorizada/cancelada). Só os ATOS usam este
/// classificador; nas LEITURAS a falha segue comum ("indisponível").
bool isUnknownAuthorityOutcome(Failure failure) {
  if (failure is NetworkFailure) return true;
  final code = failure.code ?? '';
  if (code == FiscalCodes.authorityUnknown || code == FiscalCodes.authorityUnavailable) return true;
  if (code == ClientFailureCodes.invalidResponse) return true;
  if (code == FiscalCodes.resourceBusy) return true;
  if (failure.statusCode == 500 && (code.isEmpty || code == 'INTERNAL')) return true;
  return code.isEmpty && _gatewayStatuses.contains(failure.statusCode);
}

const _gatewayStatuses = {408, 502, 503, 504};

/// Teto do motivo do "Manter a nota" (DTO da API: 1–255).
const int fiscalCancelWaiverReasonMax = 255;

/// Resultado do Transmitir (nfse-api — 201 só com A).
class ServiceOrderTransmitResult extends Equatable {
  const ServiceOrderTransmitResult({
    required this.invoiceId,
    this.attempt = 0,
    this.accessKey,
    this.nfseNumber,
  });

  final int invoiceId;
  final int attempt;
  final String? accessKey;
  final String? nfseNumber;

  factory ServiceOrderTransmitResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderTransmitResult(
        invoiceId:  jsonInt(json['invoiceId']) ?? 0,
        attempt:    jsonInt(json['attempt']) ?? 0,
        accessKey:  json['accessKey']?.toString(),
        nfseNumber: json['nfseNumber']?.toString(),
      );

  @override
  List<Object?> get props => [invoiceId, attempt, accessKey, nfseNumber];
}

/// Resultado do Consultar (nfse-api — `POST …/refresh`).
class ServiceOrderFiscalRefreshResult extends Equatable {
  const ServiceOrderFiscalRefreshResult({
    this.changed = false,
    this.kind,
    this.accessKey,
  });

  /// true = a consulta trouxe voz nova.
  final bool changed;

  /// Kind da voz nova — só para escolher a mensagem.
  final String? kind;
  final String? accessKey;

  factory ServiceOrderFiscalRefreshResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalRefreshResult(
        changed:   json['changed'] == true,
        kind:      json['kind'] as String?,
        accessKey: json['accessKey']?.toString(),
      );

  @override
  List<Object?> get props => [changed, kind, accessKey];
}

/// Resultado do Reconferir (nfse-api — `POST …/reconfirm`, D-F109). O
/// [verdict] só escolhe a FRASE (`nao-exigida` ≠ "pode cancelar") — quem
/// decide é o plano relido.
class ServiceOrderFiscalReconfirmResult extends Equatable {
  const ServiceOrderFiscalReconfirmResult({
    this.needed = false,
    this.found = false,
    this.verdict,
  });

  final bool needed;

  /// true = o fisco TEM a NFS-e — reconciliada como autorizada.
  final bool found;
  final String? verdict;

  factory ServiceOrderFiscalReconfirmResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalReconfirmResult(
        needed:  json['needed'] == true,
        found:   json['found'] == true,
        verdict: json['verdict']?.toString(),
      );

  @override
  List<Object?> get props => [needed, found, verdict];
}

/// Resultado do cancelamento NO FISCO (nfse-api — `POST …/cancel`). O efeito
/// na nota é o PRÓXIMO passo (`POST /api/billing/cancel` no ERP — D-F28).
class ServiceOrderFiscalCancelResult extends Equatable {
  const ServiceOrderFiscalCancelResult({
    required this.invoiceId,
    this.atAuthority = true,
    this.warnings = const [],
  });

  final int invoiceId;

  /// false = a voz C já existia (idempotente).
  final bool atAuthority;
  final List<String> warnings;

  factory ServiceOrderFiscalCancelResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFiscalCancelResult(
        invoiceId:   jsonInt(json['invoiceId']) ?? 0,
        atAuthority: json['atAuthority'] != false,
        warnings: (json['warnings'] as List<dynamic>? ?? [])
            .map((w) => w.toString())
            .where((w) => w.isNotEmpty)
            .toList(),
      );

  @override
  List<Object?> get props => [invoiceId, atAuthority, warnings];
}

/// Nota da OS faturada SEM NFS-e (nfse-api — `GET /v1/nfse/invoices/pending`
/// com `interfaceKey=service-orders` — D-F145).
class ServiceOrderFiscalPending extends Equatable {
  const ServiceOrderFiscalPending({
    required this.invoiceId,
    this.number,
    this.dtEmission,
  });

  final int invoiceId;
  final String? number;
  final String? dtEmission;

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

/// Teto da lista FOTOGRAFADA do lote (D-F145): o lote percorre as páginas
/// até este número de notas — o resto fica para o próximo lote.
const int fiscalBatchMaxNotes = 500;

/// Uma linha do relatório do lote (o lote roda NO APP — D-F145: 1 nota por vez).
class FiscalTransmitBatchRow extends Equatable {
  const FiscalTransmitBatchRow({
    required this.orderId,
    required this.ok,
    this.code = '',
    this.message = '',
    this.unknown = false,
    this.supportRef = '',
  });

  /// Nota que NÃO foi tentada porque o lote PAROU (erro sistêmico antes dela).
  const FiscalTransmitBatchRow.aborted(
      {required this.orderId, required this.message})
      : ok = false,
        code = abortedCode,
        unknown = false,
        supportRef = '';

  static const abortedCode = 'BATCH_ABORTED';

  final int orderId;
  final bool ok;
  final String code;
  final String message;

  /// D-F168 (= Q-F176 (a), Valdo 2026-10-13 — R6-ADV-05): desfecho
  /// DESCONHECIDO do ato no fisco (D-F155/D-F163 — [isUnknownAuthorityOutcome]):
  /// a NFS-e PODE ter sido autorizada — "incerta, consulte", nunca "recusada".
  final bool unknown;

  /// O código de suporte da falha (`ref` do servidor) — a linha incerta o mostra (R7-SOC-02: perdia código e ref).
  final String supportRef;

  /// Nota NÃO tentada (o lote parou antes dela).
  bool get notTried => code == abortedCode;

  @override
  List<Object?> get props => [orderId, ok, code, message, unknown, supportRef];
}

/// Relatório do lote — contadores SEMPRE recontados das linhas.
class FiscalTransmitBatchReport extends Equatable {
  const FiscalTransmitBatchReport({
    this.transmitted = 0,
    this.refused = 0,
    this.uncertain = 0,
    this.notTried = 0,
    this.rows = const [],
    this.stoppedBy,
  });

  final int transmitted;

  /// Recusadas — nem o desfecho desconhecido nem as não tentadas entram.
  final int refused;

  /// D-F171 (= Q-F179 (a), Valdo 2026-10-13 — R7-SOC-02): não tentadas (o lote parou antes delas) — contador próprio.
  final int notTried;

  /// D-F168: desfecho DESCONHECIDO — "incertas, consulte".
  final int uncertain;
  final List<FiscalTransmitBatchRow> rows;

  /// O erro SISTÊMICO que parou o lote (null = rodou até o fim).
  final Failure? stoppedBy;

  int get requested => rows.length;

  List<FiscalTransmitBatchRow> get refusedRows =>
      rows.where((r) => !r.ok && !r.unknown && !r.notTried).toList();

  /// D-F171: as notas que o lote NÃO tentou (parou antes delas).
  List<FiscalTransmitBatchRow> get notTriedRows =>
      rows.where((r) => r.notTried).toList();

  /// D-F168: as notas de desfecho DESCONHECIDO (consultar antes de repetir).
  List<FiscalTransmitBatchRow> get uncertainRows =>
      rows.where((r) => !r.ok && r.unknown).toList();

  factory FiscalTransmitBatchReport.fromEntries(
          List<FiscalTransmitBatchRow> rows, {Failure? stoppedBy}) =>
      FiscalTransmitBatchReport(
        transmitted: rows.where((r) => r.ok).length,
        refused:     rows.where((r) => !r.ok && !r.unknown && !r.notTried).length,
        uncertain:   rows.where((r) => !r.ok && r.unknown).length,
        notTried:    rows.where((r) => r.notTried).length,
        rows:        List.unmodifiable(rows),
        stoppedBy:   stoppedBy,
      );

  @override
  List<Object?> get props => [transmitted, refused, uncertain, notTried, rows, stoppedBy];
}
