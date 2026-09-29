import 'package:core/core.dart';

import '../../domain/entity/establishment_issuer_entity.dart';

/// Datasource DEDICADO do sub-recurso EMISSOR FISCAL do estabelecimento
/// (/api/establishment/issuer — Onda 3). Consumido pela seção autônoma da
/// aba "Emissor fiscal" (mesmo padrão do Canal API da conta bancária): a
/// seção carrega/salva por aqui e fala com a ponte de feedback; o bloc do
/// form NÃO entra, porque a habilitação e o certificado têm ciclo próprio
/// (o PUT do estabelecimento não os toca).
///
/// O institutionId é sempre implícito (token) — NUNCA existe `:id` na URL.
abstract class EstablishmentIssuerDatasource {
  Future<EstablishmentIssuerView> get();

  /// Cria/atualiza a habilitação do [model] ('SE' | '55' | '65').
  Future<EstablishmentIssuerView> saveIssuer(String model,
      {required String environment, required String serie});

  /// Remove a habilitação (409 FISCAL_ISSUER_HAS_LIVE_TRANSMISSIONS quando
  /// há transmissão viva — a ponte mostra a mensagem da API).
  Future<void> removeIssuer(String model);

  /// WRITE-ONLY: o .pfx (base64) + senha abrem o arquivo na API; só o par
  /// PEM fica no cofre. Nada do arquivo/senha volta — a resposta é só a
  /// situação do certificado (presença + validade), NÃO a visão inteira:
  /// quem precisa dos `enabled` recalculados recarrega o [get].
  /// Um certificado por estabelecimento, válido para H e P (D-N31).
  /// 400 FISCAL_CERT_INVALID · 409 FISCAL_CERT_EXPIRED.
  Future<IssuerCertStatus> saveCertificate(
      {required String pfxBase64, required String password});

  /// Apaga o par do cofre (as habilitações ficam, desabilitadas).
  Future<IssuerCertStatus> removeCertificate();
}

class EstablishmentIssuerDatasourceImpl
    implements EstablishmentIssuerDatasource {
  const EstablishmentIssuerDatasourceImpl({required this.client});

  final ApiClient client;

  static const _base = '/api/establishment/issuer';

  Map<String, dynamic> _data(Map<String, dynamic> json) =>
      json['data'] as Map<String, dynamic>? ?? const {};

  EstablishmentIssuerView _view(Map<String, dynamic> json) =>
      EstablishmentIssuerView.fromJson(_data(json));

  IssuerCertStatus _cert(Map<String, dynamic> json) =>
      IssuerCertStatus.fromJson(_data(json));

  @override
  Future<EstablishmentIssuerView> get() async => _view(await client.get(_base));

  @override
  Future<EstablishmentIssuerView> saveIssuer(String model,
          {required String environment, required String serie}) async =>
      _view(await client.put('$_base/$model', {
        'environment': environment,
        'serie': serie.trim(),
      }));

  @override
  Future<void> removeIssuer(String model) async {
    await client.delete('$_base/$model');
  }

  @override
  Future<IssuerCertStatus> saveCertificate(
          {required String pfxBase64, required String password}) async =>
      _cert(await client.put('$_base/certificate', {
        'pfxBase64': pfxBase64,
        'password': password,
      }));

  @override
  Future<IssuerCertStatus> removeCertificate() async =>
      _cert(await client.delete('$_base/certificate'));
}
