import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// EMISSOR FISCAL do estabelecimento — espelho de GET /v1/emitter da
/// nfse-api (F2b, D-F4/D-F137; antes /api/establishment/issuer do ERP). Duas
/// coisas distintas viajam
/// no mesmo envelope:
///
/// - [EstablishmentIssuer]: a HABILITAÇÃO por modelo (linha de
///   tb_establishment_issuer — ambiente + série); `enabled` é DERIVADO pela
///   API (linha + certificado válido — Q-E4).
/// - [IssuerCertStatus]: o certificado A1 ÚNICO do estabelecimento (D-N31,
///   Valdo 2026-09-28): o MESMO par serve a homologação (H) e a produção
///   (P) e a todos os modelos. O que a tela vê é só presença + validade +
///   CNPJ lidos do arquivo — o .pfx e a senha NUNCA voltam.

/// Modelos de documento que a tela oferece — D-F137 (= Q-F145 (a), Valdo
/// 2026-10-13): só a NFS-e (SE), pela nfse-api. O 55 saiu da aba (a nfse-api
/// recusa 55/65 e a nfe-api não existe ainda); a série do 55 segue
/// só-leitura no ERP (D-F112) até o 1º cliente de mercadoria.
const kIssuerModels = ['SE'];

/// Faixa da série do DPS aceita pela nfse-api (1–49999; 50000+ é do emissor
/// nacional) — o app recusa ANTES, com a mesma regra da API.
const kIssuerSerieMin = 1;
const kIssuerSerieMax = 49999;

/// A série digitada está na forma e na faixa do contrato da nfse-api.
bool issuerSerieValid(String serie) {
  final s = serie.trim();
  if (!RegExp(r'^\d{1,5}$').hasMatch(s)) return false;
  final n = int.parse(s);
  return n >= kIssuerSerieMin && n <= kIssuerSerieMax;
}

/// Ambientes de EMISSÃO da habilitação por modelo: H = homologação ·
/// P = produção. O certificado não é por ambiente (D-N31).
const kIssuerEnvironments = ['H', 'P'];

/// Validade do certificado A1 lida do arquivo pela API (derivada — nunca
/// gravada).
class IssuerCertificateInfo extends Equatable {
  const IssuerCertificateInfo({
    this.subject = '',
    this.issuer = '',
    this.notBefore = '',
    this.notAfter = '',
    this.daysToExpire = 0,
    this.expired = false,
    this.notYetValid = false,
    this.cnpj,
  });

  final String  subject;
  final String  issuer;

  /// ISO 8601 do início da vigência (vazio quando a API não o traz) —
  /// [notBeforeDate] dá só a data.
  final String  notBefore;

  /// ISO 8601 (`2027-09-03T00:00:00.000Z`) — [notAfterDate] dá só a data.
  final String  notAfter;
  final int     daysToExpire;
  final bool    expired;

  /// Ainda não vigente (notBefore no futuro) — o fisco recusaria o
  /// handshake; a API já não grava um assim, mas a leitura do cofre é
  /// fiel ao arquivo.
  final bool    notYetValid;

  /// CNPJ extraído do certificado (null quando o A1 não o traz).
  final String? cnpj;

  static String _dateOf(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;

  /// `AAAA-MM-DD` do [notBefore] (tolerante a string curta).
  String get notBeforeDate => _dateOf(notBefore);

  /// `AAAA-MM-DD` do [notAfter] (tolerante a string curta).
  String get notAfterDate => _dateOf(notAfter);

  factory IssuerCertificateInfo.fromJson(Map<String, dynamic> json) =>
      IssuerCertificateInfo(
        subject:      json['subject'] as String? ?? '',
        issuer:       json['issuer'] as String? ?? '',
        notBefore:    json['notBefore'] as String? ?? '',
        notAfter:     json['notAfter'] as String? ?? '',
        daysToExpire: jsonInt(json['daysToExpire']) ?? 0,
        expired:      json['expired'] == true,
        notYetValid:  json['notYetValid'] == true,
        cnpj:         json['cnpj'] as String?,
      );

  @override
  List<Object?> get props => [
        subject, issuer, notBefore, notAfter, daysToExpire, expired,
        notYetValid, cnpj,
      ];
}

/// Presença do par (certificado + chave) no cofre do estabelecimento +
/// validade. Um só por estabelecimento (D-N31).
class IssuerCertStatus extends Equatable {
  const IssuerCertStatus({
    this.certificate = false,
    this.privateKey = false,
    this.certificateInfo,
  });

  final bool certificate;
  final bool privateKey;
  final IssuerCertificateInfo? certificateInfo;

  /// O par está no cofre (o upload do .pfx grava os dois juntos).
  bool get present => certificate && privateKey;

  /// Presente, não vencido e já vigente — o que torna um modelo
  /// "habilitado" (espelho de `isIssuerEnabled` da API).
  bool get valid =>
      present &&
      !(certificateInfo?.expired ?? false) &&
      !(certificateInfo?.notYetValid ?? false);

  factory IssuerCertStatus.fromJson(Map<String, dynamic> json) =>
      IssuerCertStatus(
        certificate: json['certificate'] == true,
        privateKey:  json['privateKey'] == true,
        certificateInfo: json['certificateInfo'] is Map<String, dynamic>
            ? IssuerCertificateInfo.fromJson(
                json['certificateInfo'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [certificate, privateKey, certificateInfo];
}

/// Habilitação de UM modelo (linha de tb_establishment_issuer).
class EstablishmentIssuer extends Equatable {
  const EstablishmentIssuer({
    required this.model,
    this.environment = 'H',
    this.serie = '',
    this.enabled = false,
    this.authority = '',
    this.cutoverAt,
  });

  /// 'SE' NFS-e nacional · '55' NF-e · '65' NFC-e.
  final String model;

  /// 'H' homologação · 'P' produção (ambiente de EMISSÃO do modelo).
  final String environment;

  /// Série do documento (1–5 dígitos).
  final String serie;

  /// DERIVADO pela API: linha + certificado do estabelecimento válido.
  final bool enabled;

  /// 'ADN' | 'SEFAZ' — quem recebe o documento (derivado do modelo).
  final String authority;

  /// D-F39: desde quando a nfse-api emite por esta habilitação; null =
  /// RÉPLICA do ERP (a virada ainda não aconteceu — só leitura).
  final String? cutoverAt;

  factory EstablishmentIssuer.fromJson(Map<String, dynamic> json) =>
      EstablishmentIssuer(
        model:       '${json['model'] ?? ''}',
        environment: json['environment'] as String? ?? 'H',
        serie:       '${json['serie'] ?? ''}',
        enabled:     json['enabled'] == true,
        authority:   json['authority'] as String? ?? '',
        cutoverAt:   json['cutoverAt']?.toString(),
      );

  @override
  List<Object?> get props => [model, environment, serie, enabled, authority, cutoverAt];
}

/// Envelope de GET /api/establishment/issuer e de PUT /issuer/:model
/// (as rotas do certificado devolvem só o [IssuerCertStatus]).
class EstablishmentIssuerView extends Equatable {
  const EstablishmentIssuerView({
    this.issuers = const [],
    this.certificate = const IssuerCertStatus(),
  });

  final List<EstablishmentIssuer> issuers;

  /// Certificado ÚNICO do estabelecimento — sempre um objeto (vazio quando
  /// não há nada no cofre).
  final IssuerCertStatus certificate;

  /// Habilitação do [model] (null = não configurado).
  EstablishmentIssuer? issuerFor(String model) {
    for (final i in issuers) {
      if (i.model == model) return i;
    }
    return null;
  }

  /// Estado exibido pelo badge do modelo: `enabled` (habilitado) ·
  /// `noCertificate` (linha existe mas o estabelecimento não tem
  /// certificado válido) · `notConfigured` (sem linha).
  ///
  /// F2b (parecer do guardião): o `enabled` da nfse-api = virada feita E A1
  /// vigente — "sem certificado" derivado de `!enabled` mentia antes da
  /// virada. O selo vem dos FATOS: `awaitingCutover` = a emissão ainda é do
  /// ERP (cutoverAt nulo).
  IssuerBadge badgeFor(String model) {
    final issuer = issuerFor(model);
    if (issuer == null) return IssuerBadge.notConfigured;
    if (issuer.enabled) return IssuerBadge.enabled;
    if (issuer.cutoverAt == null) return IssuerBadge.awaitingCutover;
    return IssuerBadge.noCertificate;
  }

  factory EstablishmentIssuerView.fromJson(Map<String, dynamic> json) {
    final issuersJson = json['issuers'] as List<dynamic>? ?? const [];
    final certJson = json['certificate'];
    return EstablishmentIssuerView(
      issuers: issuersJson
          .whereType<Map<String, dynamic>>()
          .map(EstablishmentIssuer.fromJson)
          .toList(),
      certificate: certJson is Map<String, dynamic>
          ? IssuerCertStatus.fromJson(certJson)
          : const IssuerCertStatus(),
    );
  }

  @override
  List<Object?> get props => [issuers, certificate];
}

enum IssuerBadge { enabled, awaitingCutover, noCertificate, notConfigured }
