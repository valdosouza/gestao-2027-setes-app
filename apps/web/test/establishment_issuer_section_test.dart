// Seção AUTÔNOMA "Emissor fiscal" do Meu Estabelecimento (Onda 3 — NFS-e
// pelo Padrão Nacional): renderiza o certificado ÚNICO do estabelecimento
// (presença, validade, CNPJ — D-N31: o mesmo A1 serve a homologação e a
// produção) e a habilitação por modelo (badge derivado do `enabled` da
// API); valida a série (1–5 dígitos) e a senha do .pfx pela PONTE (dialog +
// foco); o upload manda o arquivo em base64 + senha, limpa a senha e
// RECARREGA a visão (as rotas do certificado devolvem só o status);
// "Remover" pede decisão tipada antes de chamar a API. Datasource e seletor
// de arquivo FALSOS — os endpoints da API ainda podem não responder.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
// Carga direta das traduções no teste (sem o widget EasyLocalization) —
// Localization/Translations não saem pelo barrel do pacote.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/establishment/data/datasource/establishment_issuer_datasource.dart';
import 'package:setes_web/app/modules/establishment/domain/entity/establishment_issuer_entity.dart';
import 'package:setes_web/app/modules/establishment/presentation/widget/establishment_issuer_section.dart';

const _validCert = IssuerCertStatus(
  certificate: true,
  privateKey: true,
  certificateInfo: IssuerCertificateInfo(
    notAfter: '2027-03-15T23:59:59.000Z',
    daysToExpire: 175,
    cnpj: '12345678000199',
  ),
);

/// Registra as chamadas e devolve a visão configurada (mutável pelo teste).
/// Imita a derivação da API: `enabled` de cada modelo = certificado válido
/// do estabelecimento (recalculado a cada GET/PUT, como a API faz).
class _FakeDatasource implements EstablishmentIssuerDatasource {
  _FakeDatasource({required this.issuers, required this.certificate});

  List<EstablishmentIssuer> issuers;
  IssuerCertStatus certificate;
  final calls = <String>[];
  Map<String, dynamic>? lastCertificateBody;
  Failure? failOn;

  void _maybeFail(String call) {
    if (failOn != null) throw failOn!;
    calls.add(call);
  }

  EstablishmentIssuerView get _view => EstablishmentIssuerView(
        issuers: [
          for (final i in issuers)
            EstablishmentIssuer(
              model: i.model,
              environment: i.environment,
              serie: i.serie,
              enabled: certificate.valid,
              authority: i.authority,
            ),
        ],
        certificate: certificate,
      );

  @override
  Future<EstablishmentIssuerView> get() async {
    calls.add('get');
    return _view;
  }

  @override
  Future<EstablishmentIssuerView> saveIssuer(String model,
      {required String environment, required String serie}) async {
    _maybeFail('saveIssuer:$model:$environment:$serie');
    issuers = [
      ...issuers.where((i) => i.model != model),
      EstablishmentIssuer(model: model, environment: environment, serie: serie),
    ];
    return _view;
  }

  @override
  Future<void> removeIssuer(String model) async {
    _maybeFail('removeIssuer:$model');
    issuers = issuers.where((i) => i.model != model).toList();
  }

  @override
  Future<IssuerCertStatus> saveCertificate(
      {required String pfxBase64, required String password}) async {
    _maybeFail('saveCertificate');
    lastCertificateBody = {'pfxBase64': pfxBase64, 'password': password};
    certificate = const IssuerCertStatus(
      certificate: true,
      privateKey: true,
      certificateInfo: IssuerCertificateInfo(
        notAfter: '2027-06-30T00:00:00.000Z',
        daysToExpire: 280,
        cnpj: '12345678000199',
      ),
    );
    return certificate;
  }

  @override
  Future<IssuerCertStatus> removeCertificate() async {
    _maybeFail('removeCertificate');
    certificate = const IssuerCertStatus();
    return certificate;
  }
}

/// Certificado válido no cofre; SE habilitada em H; 55 sem linha.
_FakeDatasource _withCertificate() => _FakeDatasource(
      issuers: const [
        EstablishmentIssuer(model: 'SE', environment: 'H', serie: '1', authority: 'ADN'),
      ],
      certificate: _validCert,
    );

/// Cofre vazio; SE com linha (H) — desabilitada por falta de certificado.
_FakeDatasource _withoutCertificate() => _FakeDatasource(
      issuers: const [
        EstablishmentIssuer(model: 'SE', environment: 'H', serie: '1', authority: 'ADN'),
      ],
      certificate: const IssuerCertStatus(),
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, _FakeDatasource ds,
    {Future<PickedPfx?> Function()? pickPfx}) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(EstablishmentIssuerSection(
    datasource: ds,
    pickPfx: pickPfx ?? () async => null,
  )));
  await tester.pumpAndSettle();
}

/// byType casa o runtimeType EXATO — o predicate cobre Elevated/Outlined/
/// TextButton do SetesButton. [index] escolhe a ocorrência: "Remover" é
/// [0] certificado, [1] SE, [2] 55.
Finder _button(String text, {int index = 0}) => find
    .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
    .at(index);

Finder get _passwordField =>
    find.widgetWithText(TextFormField, 'Senha do arquivo .pfx');

Future<void> _tapOk(WidgetTester tester) async {
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync())
        as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
  });

  testWidgets('carrega pelo datasource e mostra o certificado ÚNICO + badges derivados',
      (tester) async {
    final ds = _withCertificate();
    await _pump(tester, ds);

    expect(ds.calls, ['get']);
    // UM bloco de certificado (sem rótulo de ambiente): presença, validade, CNPJ.
    expect(find.text('Certificado: presente'), findsOneWidget);
    expect(find.text('Chave privada: presente'), findsOneWidget);
    expect(find.text('Certificado: ausente'), findsNothing);
    expect(find.text('Válido até 2027-03-15 (175 dias)'), findsOneWidget);
    expect(find.text('CNPJ do certificado: 12345678000199'), findsOneWidget);
    expect(_passwordField, findsOneWidget, reason: 'uma senha só — não é por ambiente');
    expect(find.text('Enviar certificado (.pfx)'), findsOneWidget);
    // O ambiente só aparece na HABILITAÇÃO por modelo (dropdown), nunca como
    // título de bloco de certificado.
    expect(find.text('Ambiente de emissão'), findsNWidgets(kIssuerModels.length));
    // Badges: SE habilitada (linha + certificado válido); 55 sem linha.
    expect(find.text('Habilitado'), findsOneWidget);
    expect(find.text('Não configurado'), findsOneWidget);
    expect(find.text('Sem certificado'), findsNothing);
    // Série vinda do servidor preenche o campo.
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);
  });

  testWidgets('sem certificado no cofre: linha existente vira "Sem certificado"',
      (tester) async {
    final ds = _withoutCertificate();
    await _pump(tester, ds);

    expect(find.text('Certificado: ausente'), findsOneWidget);
    expect(find.text('Chave privada: ausente'), findsOneWidget);
    expect(find.text('Sem certificado'), findsOneWidget);
    expect(find.text('Habilitado'), findsNothing);
    // "Remover" do certificado fica desabilitado quando não há par no cofre.
    expect(tester.widget<ButtonStyleButton>(_button('Remover', index: 0)).enabled,
        isFalse);
  });

  testWidgets('certificado ainda não vigente mostra a linha "Só vale a partir de"',
      (tester) async {
    final ds = _FakeDatasource(
      issuers: const [],
      certificate: const IssuerCertStatus(
        certificate: true,
        privateKey: true,
        certificateInfo: IssuerCertificateInfo(
          notBefore: '2027-01-10T00:00:00.000Z',
          notAfter: '2028-01-10T00:00:00.000Z',
          daysToExpire: 470,
          notYetValid: true,
        ),
      ),
    );
    await _pump(tester, ds);

    expect(find.text('Só vale a partir de 2027-01-10'), findsOneWidget);
    expect(find.textContaining('Válido até'), findsNothing);
  });

  testWidgets('série inválida bloqueia pela ponte (dialog) sem chamar a API', (tester) async {
    final ds = _withCertificate();
    await _pump(tester, ds);

    // Limpa a série da NFS-e (campo "Série do documento" com '1') e salva.
    await tester.enterText(find.widgetWithText(TextFormField, '1'), '');
    await tester.tap(_button('Salvar', index: 0));
    await tester.pumpAndSettle();

    expect(find.text('Informe a série do documento com 1 a 5 dígitos'), findsOneWidget);
    await _tapOk(tester);
    expect(ds.calls, ['get'], reason: 'nada foi salvo');
  });

  testWidgets('salvar habilitação manda ambiente + série e o badge segue o enabled da API',
      (tester) async {
    final ds = _withCertificate();
    await _pump(tester, ds);

    // NF-e (2º bloco, sem linha): série 00003 no ambiente default (H) →
    // com certificado válido no cofre a API devolve enabled → "Habilitado".
    final serieFields = find.widgetWithText(TextFormField, 'Série do documento');
    await tester.enterText(serieFields.at(1), '00003');
    await tester.tap(_button('Salvar', index: 1));
    await tester.pumpAndSettle();

    expect(ds.calls, ['get', 'saveIssuer:55:H:00003']);
    expect(find.text('Habilitação do documento salva'), findsOneWidget);
    expect(find.text('Habilitado'), findsNWidgets(2));
    expect(find.text('Não configurado'), findsNothing);
  });

  testWidgets('remover habilitação pede decisão; Cancelar não chama a API', (tester) async {
    final ds = _withCertificate();
    await _pump(tester, ds);

    // Botões "Remover": [0] certificado, [1] SE, [2] 55 (desabilitado, sem linha).
    await tester.tap(_button('Remover', index: 1));
    await tester.pumpAndSettle();
    expect(find.text('Remover a habilitação de NFS-e (Padrão Nacional)?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(ds.calls, ['get']);

    // Confirma: DELETE + recarga do GET → SE vira "Não configurado".
    await tester.tap(_button('Remover', index: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover').last); // "Sim" rotulado como Remover
    await tester.pumpAndSettle();
    expect(ds.calls, ['get', 'removeIssuer:SE', 'get']);
    expect(find.text('Não configurado'), findsNWidgets(2));
    expect(find.text('Habilitado'), findsNothing);
  });

  testWidgets('upload sem senha bloqueia pela ponte; com senha manda base64, limpa a senha e recarrega',
      (tester) async {
    final ds = _withoutCertificate();
    var picks = 0;
    await _pump(tester, ds, pickPfx: () async {
      picks++;
      return PickedPfx(name: 'setes.pfx', bytes: Uint8List.fromList([1, 2, 3, 250]));
    });

    // Sem senha → dialog, sem abrir o seletor.
    await tester.tap(_button('Enviar certificado (.pfx)'));
    await tester.pumpAndSettle();
    expect(find.text('Informe a senha do arquivo .pfx antes de enviar o certificado'), findsOneWidget);
    await _tapOk(tester);
    expect(picks, 0);
    expect(ds.lastCertificateBody, isNull);

    // Com senha: seletor abre, arquivo vai em base64 + senha (sem ambiente);
    // a senha some; a visão é RECARREGADA (o PUT devolve só o status).
    await tester.enterText(_passwordField, 'segredo');
    await tester.tap(_button('Enviar certificado (.pfx)'));
    await tester.pumpAndSettle();

    expect(picks, 1);
    expect(ds.calls, ['get', 'saveCertificate', 'get']);
    expect(ds.lastCertificateBody!['pfxBase64'], base64Encode([1, 2, 3, 250]));
    expect(ds.lastCertificateBody!['password'], 'segredo');
    expect(tester.widget<TextFormField>(_passwordField).controller!.text, '',
        reason: 'write-only: a senha sai da tela após o envio');
    expect(find.text('Certificado enviado ao cofre'), findsOneWidget);
    // O cofre agora tem o par válido → a linha SE passa a "Habilitado" na
    // recarga (enabled derivado pela API, um certificado para tudo).
    expect(find.text('Certificado: ausente'), findsNothing);
    expect(find.text('CNPJ do certificado: 12345678000199'), findsOneWidget);
    expect(find.text('Habilitado'), findsOneWidget);
    expect(find.text('Sem certificado'), findsNothing);
  });

  testWidgets('remover certificado pede decisão (sem ambiente); confirmar apaga e recarrega',
      (tester) async {
    final ds = _withCertificate();
    await _pump(tester, ds);

    await tester.tap(_button('Remover', index: 0));
    await tester.pumpAndSettle();
    expect(
        find.text('Remover o certificado do estabelecimento? '
            'Todos os documentos deixam de ser habilitados.'),
        findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(ds.calls, ['get']);

    await tester.tap(_button('Remover', index: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover').last);
    await tester.pumpAndSettle();
    expect(ds.calls, ['get', 'removeCertificate', 'get']);
    expect(find.text('Certificado removido'), findsOneWidget);
    expect(find.text('Certificado: ausente'), findsOneWidget);
    // A habilitação FICA, mas desabilitada.
    expect(find.text('Sem certificado'), findsOneWidget);
    expect(find.text('Habilitado'), findsNothing);
  });

  testWidgets('erro da API no upload chega pela ponte (dialog com a mensagem)', (tester) async {
    final ds = _withCertificate();
    await _pump(tester, ds, pickPfx: () async =>
        PickedPfx(name: 'x.pfx', bytes: Uint8List.fromList([0])));
    ds.failOn = const Failure(
        message: 'Senha incorreta ou arquivo inválido',
        statusCode: 400,
        code: 'FISCAL_CERT_INVALID');

    await tester.enterText(_passwordField, 'errada');
    await tester.tap(_button('Enviar certificado (.pfx)'));
    await tester.pumpAndSettle();

    expect(find.text('Senha incorreta ou arquivo inválido'), findsOneWidget);
    await _tapOk(tester);
    expect(ds.lastCertificateBody, isNull);
    expect(ds.calls, ['get'], reason: 'falha não recarrega a visão');
  });
}
