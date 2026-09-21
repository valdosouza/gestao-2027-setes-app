// Contrato de dados do CANAL API da conta bancária (Onda 2 — D-I2/D-I3/D-I4):
// parse de GET /api/bank-accounts/:id/channel (canal, presença dos segredos,
// validade do certificado, adaptador do banco, caminho do webhook) e da prova
// de vida. O conteúdo dos segredos NUNCA volta da API — a tela só vê presença.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/bank_accounts/domain/entity/bank_account_channel_entity.dart';

void main() {
  group('BankAccountChannel', () {
    test('fromJson lê o canal com ambiente, client_id e token de entrada', () {
      final ch = BankAccountChannel.fromJson({
        'bankAccountId': '5',
        'environment': 'P',
        'clientId': 'efda75af-0000',
        'active': 'N',
        'inboundToken': 'tok-abc',
      });
      expect(ch.bankAccountId, 5);
      expect(ch.environment, 'P');
      expect(ch.clientId, 'efda75af-0000');
      expect(ch.active, 'N');
      expect(ch.inboundToken, 'tok-abc');
    });

    test('defaults: sandbox, ativo, sem client_id, token vazio', () {
      final ch = BankAccountChannel.fromJson({'bankAccountId': 1});
      expect(ch.environment, 'S');
      expect(ch.active, 'S');
      expect(ch.clientId, isNull);
      expect(ch.inboundToken, '');
    });
  });

  group('ChannelSecretsStatus', () {
    test('complete só com os três segredos presentes', () {
      expect(const ChannelSecretsStatus().complete, isFalse);
      expect(
        const ChannelSecretsStatus(certificate: true, privateKey: true).complete,
        isFalse,
        reason: 'falta o client_secret',
      );
      expect(
        const ChannelSecretsStatus(certificate: true, privateKey: true, clientSecret: true).complete,
        isTrue,
      );
    });

    test('fromJson lê presença + validade do certificado (derivada do PEM)', () {
      final s = ChannelSecretsStatus.fromJson({
        'certificate': true,
        'privateKey': true,
        'clientSecret': false,
        'certificateInfo': {
          'subject': 'CN=EMPRESA, OU=efda75af',
          'issuer': 'API Intermediate Certificate Authority',
          'notAfter': '2027-09-03T00:00:00.000Z',
          'daysToExpire': 349,
          'expired': false,
        },
      });
      expect(s.certificate, isTrue);
      expect(s.clientSecret, isFalse);
      expect(s.complete, isFalse);
      expect(s.certificateInfo, isNotNull);
      expect(s.certificateInfo!.daysToExpire, 349);
      expect(s.certificateInfo!.expired, isFalse);
      expect(s.certificateInfo!.issuer, contains('Inter'));
    });

    test('sem certificado no cofre não há certificateInfo', () {
      final s = ChannelSecretsStatus.fromJson({'certificate': false, 'certificateInfo': null});
      expect(s.certificateInfo, isNull);
      expect(s.complete, isFalse);
    });

    test('certificado vencido chega marcado', () {
      final info = ChannelCertificateInfo.fromJson({'daysToExpire': -3, 'expired': true});
      expect(info.expired, isTrue);
      expect(info.daysToExpire, -3);
    });
  });

  group('BankAccountChannelView', () {
    test('conta sem canal: channel/secrets nulos, banco e adaptador informados', () {
      final v = BankAccountChannelView.fromJson({
        'channel': null,
        'secrets': null,
        'bankNumber': '001',
        'adapterSupported': false,
        'webhookPath': null,
      });
      expect(v.channel, isNull);
      expect(v.secrets, isNull);
      expect(v.bankNumber, '001');
      expect(v.adapterSupported, isFalse, reason: 'banco 001 não tem adaptador');
      expect(v.webhookPath, isNull);
    });

    test('conta do Inter com canal: adaptador suportado e caminho do webhook', () {
      final v = BankAccountChannelView.fromJson({
        'channel': {'bankAccountId': 2, 'environment': 'S', 'inboundToken': 't1'},
        'secrets': {'certificate': true, 'privateKey': true, 'clientSecret': true},
        'bankNumber': '077',
        'adapterSupported': true,
        'webhookPath': '/hooks/bank-channel/1/t1',
      });
      expect(v.channel!.bankAccountId, 2);
      expect(v.secrets!.complete, isTrue);
      expect(v.adapterSupported, isTrue);
      expect(v.webhookPath, endsWith('/t1'));
    });

    test('payload vazio não quebra (data ausente na resposta)', () {
      final v = BankAccountChannelView.fromJson(const {});
      expect(v.channel, isNull);
      expect(v.bankNumber, '');
      expect(v.adapterSupported, isFalse);
    });
  });

  group('ChannelTestResult', () {
    test('lê ambiente e a URL do webhook aninhada', () {
      final r = ChannelTestResult.fromJson({
        'environment': 'S',
        'webhook': {'url': 'https://app.setes.com.br/hooks/bank-channel/1/t1'},
      });
      expect(r.environment, 'S');
      expect(r.webhookUrl, startsWith('https://'));
    });

    test('sem webhook cadastrado no banco a URL é nula', () {
      final r = ChannelTestResult.fromJson({'environment': 'P', 'webhook': null});
      expect(r.environment, 'P');
      expect(r.webhookUrl, isNull);
    });
  });
}
