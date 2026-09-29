// Contrato de dados do EMISSOR FISCAL do estabelecimento (Onda 3 — NFS-e
// pelo Padrão Nacional): parse do envelope de GET /api/establishment/issuer
// (habilitação por modelo + certificado A1 ÚNICO do estabelecimento — D-N31:
// o mesmo par serve a homologação e a produção), `enabled` derivado pela
// API, presença/validade do certificado e o estado do badge.
// O .pfx e a senha NUNCA voltam — a tela só vê presença + validade + CNPJ.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/establishment/domain/entity/establishment_issuer_entity.dart';

void main() {
  group('EstablishmentIssuer', () {
    test('fromJson lê modelo, ambiente, série, enabled e autoridade', () {
      final i = EstablishmentIssuer.fromJson({
        'model': 'SE',
        'environment': 'P',
        'serie': '00001',
        'enabled': true,
        'authority': 'ADN',
      });
      expect(i.model, 'SE');
      expect(i.environment, 'P');
      expect(i.serie, '00001');
      expect(i.enabled, isTrue);
      expect(i.authority, 'ADN');
    });

    test('defaults: ambiente H, série vazia, desabilitado; série numérica vira texto', () {
      final i = EstablishmentIssuer.fromJson({'model': '55', 'serie': 1});
      expect(i.environment, 'H');
      expect(i.serie, '1');
      expect(i.enabled, isFalse, reason: 'enabled ausente = false');
      expect(i.authority, '');
    });
  });

  group('IssuerCertStatus', () {
    test('present só com certificado E chave; valid exige não vencido', () {
      expect(const IssuerCertStatus().present, isFalse);
      expect(const IssuerCertStatus(certificate: true).present, isFalse,
          reason: 'falta a chave privada');
      const ok = IssuerCertStatus(certificate: true, privateKey: true);
      expect(ok.present, isTrue);
      expect(ok.valid, isTrue, reason: 'sem info de validade = não vencido');
      const expired = IssuerCertStatus(
        certificate: true,
        privateKey: true,
        certificateInfo: IssuerCertificateInfo(expired: true, daysToExpire: -2),
      );
      expect(expired.present, isTrue);
      expect(expired.valid, isFalse);
    });

    test('valid exige também já vigente (notYetValid = false)', () {
      const future = IssuerCertStatus(
        certificate: true,
        privateKey: true,
        certificateInfo: IssuerCertificateInfo(
          notBefore: '2027-01-01T00:00:00.000Z',
          notAfter: '2028-01-01T00:00:00.000Z',
          daysToExpire: 400,
          notYetValid: true,
        ),
      );
      expect(future.present, isTrue);
      expect(future.valid, isFalse, reason: 'espelho de isIssuerEnabled da API');
      expect(future.certificateInfo!.notBeforeDate, '2027-01-01');
    });

    test('fromJson lê presença + validade + CNPJ do certificado', () {
      final s = IssuerCertStatus.fromJson({
        'certificate': true,
        'privateKey': true,
        'certificateInfo': {
          'subject': 'CN=SETES LTDA:12345678000199',
          'issuer': 'AC Certisign RFB G5',
          'notAfter': '2027-03-15T23:59:59.000Z',
          'daysToExpire': 175,
          'expired': false,
          'notYetValid': false,
          'cnpj': '12345678000199',
        },
      });
      expect(s.present, isTrue);
      expect(s.valid, isTrue);
      final info = s.certificateInfo!;
      expect(info.cnpj, '12345678000199');
      expect(info.daysToExpire, 175);
      expect(info.notAfterDate, '2027-03-15');
      expect(info.notYetValid, isFalse);
      expect(info.notBefore, '', reason: 'ausente no payload = vazio');
    });

    test('sem certificado no cofre não há certificateInfo; cnpj pode ser null', () {
      final s = IssuerCertStatus.fromJson({'certificate': false, 'certificateInfo': null});
      expect(s.certificateInfo, isNull);
      expect(s.present, isFalse);
      final info = IssuerCertificateInfo.fromJson({'notAfter': '', 'cnpj': null});
      expect(info.cnpj, isNull);
      expect(info.notAfterDate, '');
      expect(info.notYetValid, isFalse, reason: 'notYetValid ausente = false');
    });
  });

  group('EstablishmentIssuerView', () {
    final view = EstablishmentIssuerView.fromJson({
      'issuers': [
        {'model': 'SE', 'environment': 'H', 'serie': '1', 'enabled': true, 'authority': 'ADN'},
        {'model': '55', 'environment': 'P', 'serie': '3', 'enabled': false, 'authority': 'SEFAZ'},
      ],
      'certificate': {
        'certificate': true,
        'privateKey': true,
        'certificateInfo': {'notAfter': '2027-01-01T00:00:00.000Z', 'daysToExpire': 100, 'expired': false},
      },
    });

    test('issuerFor devolve a habilitação do modelo (null = não configurado)', () {
      expect(view.issuerFor('SE')!.enabled, isTrue);
      expect(view.issuerFor('55')!.environment, 'P');
      expect(view.issuerFor('65'), isNull);
    });

    test('certificate é o objeto ÚNICO do estabelecimento (D-N31)', () {
      expect(view.certificate.present, isTrue);
      expect(view.certificate.valid, isTrue);
      expect(view.certificate.certificateInfo!.notAfterDate, '2027-01-01');
    });

    test('badge: enabled × linha com enabled false da API × sem linha', () {
      expect(view.badgeFor('SE'), IssuerBadge.enabled);
      expect(view.badgeFor('55'), IssuerBadge.noCertificate,
          reason: 'o badge segue o enabled DERIVADO pela API, não recalcula');
      expect(view.badgeFor('65'), IssuerBadge.notConfigured);
    });

    test('payload vazio não quebra: certificate vem vazio, nunca null', () {
      final v = EstablishmentIssuerView.fromJson(const {});
      expect(v.issuers, isEmpty);
      expect(v.certificate.present, isFalse);
      expect(v.certificate.certificateInfo, isNull);
      expect(v.badgeFor('SE'), IssuerBadge.notConfigured);
    });

    test('certificate null ou de tipo errado no payload vira status vazio', () {
      expect(
          EstablishmentIssuerView.fromJson({'certificate': null}).certificate.present,
          isFalse);
      expect(
          EstablishmentIssuerView.fromJson({'certificate': 'x'}).certificate.present,
          isFalse);
    });
  });
}
