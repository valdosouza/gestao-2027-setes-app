// D-F67 — dialog "Manter a nota" da OS (irmão do dialog de motivo do
// cancelamento): motivo obrigatório com UMA pendência por vez ancorada no
// campo, teto de 255 caracteres (o DTO da API recusa acima disso) e o motivo
// devolvido sem espaços nas pontas. Também fixa que as chaves i18n novas da
// seção "No fisco" existem em pt E en (chave faltando vira texto cru na tela).

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// Carga direta das traduções no teste (sem o widget EasyLocalization) —
// mesmo recurso do order_negotiation_section_test.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/service_orders/presentation/page/service_order_keep_invoice_dialog.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Chaves novas da D-F67 em forms.serviceOrder.
const _newKeys = [
  'fiscalSubstitutedRow',
  'fiscalSubstitutedDecidedRow',
  'fiscalSubstituteAccessKey',
  'fiscalSubstituteUnavailable',
  'fiscalKeep',
  'fiscalKeepTitle',
  'fiscalKeepExplain',
  'fiscalKeepReason',
  'fiscalKeepReasonRequired',
  'fiscalKeepReasonTooLong',
  'fiscalKeepDone',
  'fiscalKeepAlready',
  'fiscalKeptRow',
];

void main() {
  setUpAll(() {
    // Textos REAIS do i18n pt (o .tr() resolve pela instância estática).
    Localization.load(const Locale('pt'), translations: Translations(_load('pt')));
  });

  test('chaves i18n da D-F67 existem em pt e en (texto não vazio)', () {
    for (final lang in ['pt', 'en']) {
      final block = (_load(lang)['forms'] as Map<String, dynamic>)['serviceOrder']
          as Map<String, dynamic>;
      for (final key in _newKeys) {
        expect(block[key], isA<String>(), reason: '$lang: forms.serviceOrder.$key');
        expect((block[key] as String).trim(), isNotEmpty,
            reason: '$lang: forms.serviceOrder.$key');
      }
      // placeholders: título com o nº do documento; linha da decisão com data + motivo
      expect('{}'.allMatches(block['fiscalKeepTitle'] as String).length, 1,
          reason: lang);
      expect('{}'.allMatches(block['fiscalKeptRow'] as String).length, 2,
          reason: lang);
    }
  });

  testWidgets('motivo obrigatório (pendência ancorada), teto 255 e retorno com trim',
      (tester) async {
    String? reason;
    var closed = false;
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          reason = await showKeepInvoiceDialog(context, '7223');
          closed = true;
        },
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('forms.serviceOrder.fiscalKeepTitle'.tr(args: ['7223'])),
        findsOneWidget);
    final confirm =
        find.widgetWithText(TextButton, 'forms.serviceOrder.fiscalKeep'.tr());

    // Confirmar sem motivo → pendência (uma por vez) → OK → marca no campo
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('forms.serviceOrder.fiscalKeepReasonRequired'.tr()),
        findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.serviceOrder.fiscalKeepReasonRequired'.tr()),
        findsOneWidget);
    expect(closed, isFalse);

    // 256 caracteres → pendência do teto (a API recusaria com 400)
    await tester.enterText(find.byType(TextFormField), 'x' * 256);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('forms.serviceOrder.fiscalKeepReasonTooLong'.tr()),
        findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(closed, isFalse);

    // Corrigiu → marca some; confirma → motivo devolvido (trim)
    await tester.enterText(
        find.byType(TextFormField), '  substituta emitida pelo contador  ');
    await tester.pumpAndSettle();
    expect(find.text('forms.serviceOrder.fiscalKeepReasonTooLong'.tr()),
        findsNothing);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(reason, 'substituta emitida pelo contador');
  });

  testWidgets('desistir devolve null (nada é registrado)', (tester) async {
    String? reason = 'sentinela';
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            reason = await showKeepInvoiceDialog(context, '7223'),
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'register.cancel'.tr()));
    await tester.pumpAndSettle();
    expect(reason, isNull);
  });
}
