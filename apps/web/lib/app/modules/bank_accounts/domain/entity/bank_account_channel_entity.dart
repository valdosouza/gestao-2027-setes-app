import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// CANAL API da conta bancária (Onda 2 da fase Primeiro Cliente, D-I3/D-I4):
/// "esta conta corrente fala com o seu banco por API". Espelho de
/// GET/PUT /api/bank-accounts/:id/channel. O que a tela vê dos SEGREDOS é só
/// presença + validade do certificado — o conteúdo nunca volta da API.
class BankAccountChannel extends Equatable {
  const BankAccountChannel({
    required this.bankAccountId,
    this.environment = 'S',
    this.clientId,
    this.active = 'S',
    this.inboundToken = '',
  });

  final int     bankAccountId;

  /// 'S' sandbox · 'P' produção.
  final String  environment;
  final String? clientId;
  final String  active;

  /// Token que NÓS emitimos para o banco nos chamar (path do webhook).
  final String  inboundToken;

  factory BankAccountChannel.fromJson(Map<String, dynamic> json) =>
      BankAccountChannel(
        bankAccountId: jsonInt(json['bankAccountId']) ?? 0,
        environment:   json['environment'] as String? ?? 'S',
        clientId:      json['clientId'] as String?,
        active:        json['active'] as String? ?? 'S',
        inboundToken:  json['inboundToken'] as String? ?? '',
      );

  @override
  List<Object?> get props => [bankAccountId, environment, clientId, active, inboundToken];
}

/// Validade do certificado mTLS lida do arquivo (derivada — nunca gravada).
class ChannelCertificateInfo extends Equatable {
  const ChannelCertificateInfo({
    this.subject = '',
    this.issuer = '',
    this.notAfter = '',
    this.daysToExpire = 0,
    this.expired = false,
  });

  final String subject;
  final String issuer;
  final String notAfter;
  final int    daysToExpire;
  final bool   expired;

  factory ChannelCertificateInfo.fromJson(Map<String, dynamic> json) =>
      ChannelCertificateInfo(
        subject:      json['subject'] as String? ?? '',
        issuer:       json['issuer'] as String? ?? '',
        notAfter:     json['notAfter'] as String? ?? '',
        daysToExpire: jsonInt(json['daysToExpire']) ?? 0,
        expired:      json['expired'] == true,
      );

  @override
  List<Object?> get props => [subject, issuer, notAfter, daysToExpire, expired];
}

/// Presença dos três segredos no cofre (D-I3) + validade do certificado.
class ChannelSecretsStatus extends Equatable {
  const ChannelSecretsStatus({
    this.certificate = false,
    this.privateKey = false,
    this.clientSecret = false,
    this.certificateInfo,
  });

  final bool certificate;
  final bool privateKey;
  final bool clientSecret;
  final ChannelCertificateInfo? certificateInfo;

  bool get complete => certificate && privateKey && clientSecret;

  factory ChannelSecretsStatus.fromJson(Map<String, dynamic> json) =>
      ChannelSecretsStatus(
        certificate:  json['certificate'] == true,
        privateKey:   json['privateKey'] == true,
        clientSecret: json['clientSecret'] == true,
        certificateInfo: json['certificateInfo'] is Map<String, dynamic>
            ? ChannelCertificateInfo.fromJson(json['certificateInfo'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [certificate, privateKey, clientSecret, certificateInfo];
}

/// Resposta de GET /channel: canal (ou null), segredos, banco e caminho do webhook.
class BankAccountChannelView extends Equatable {
  const BankAccountChannelView({
    this.channel,
    this.secrets,
    this.bankNumber = '',
    this.adapterSupported = false,
    this.webhookPath,
  });

  final BankAccountChannel? channel;
  final ChannelSecretsStatus? secrets;
  final String bankNumber;

  /// Banco da conta tem adaptador de API neste sistema (derivado — D-I2).
  final bool adapterSupported;
  final String? webhookPath;

  factory BankAccountChannelView.fromJson(Map<String, dynamic> json) =>
      BankAccountChannelView(
        channel: json['channel'] is Map<String, dynamic>
            ? BankAccountChannel.fromJson(json['channel'] as Map<String, dynamic>)
            : null,
        secrets: json['secrets'] is Map<String, dynamic>
            ? ChannelSecretsStatus.fromJson(json['secrets'] as Map<String, dynamic>)
            : null,
        bankNumber:       json['bankNumber'] as String? ?? '',
        adapterSupported: json['adapterSupported'] == true,
        webhookPath:      json['webhookPath'] as String?,
      );

  @override
  List<Object?> get props => [channel, secrets, bankNumber, adapterSupported, webhookPath];
}

/// Prova de vida do canal (POST /channel/test).
class ChannelTestResult extends Equatable {
  const ChannelTestResult({this.environment = '', this.webhookUrl});

  final String  environment;
  final String? webhookUrl;

  factory ChannelTestResult.fromJson(Map<String, dynamic> json) =>
      ChannelTestResult(
        environment: json['environment'] as String? ?? '',
        webhookUrl:  (json['webhook'] as Map<String, dynamic>?)?['url'] as String?,
      );

  @override
  List<Object?> get props => [environment, webhookUrl];
}
