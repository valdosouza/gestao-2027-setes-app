// Seção NEGOCIAÇÃO do pedido (módulo orders) e dialog de CHEQUES do
// faturamento (prompt_negociacao_pedido.md D3/D5/D6): via simples ×
// elaborada, "Negociar parcelas" copia o preview, soma ≠ base bloqueia o
// Salvar, forma por parcela vazia = null (nunca o id do cabeçalho), pedido
// faturado somente leitura; cheques por parcela com soma = parcela.
//
// Com SETES_SHOT_DIR definido, grava PNGs das telas (validação visual sem
// subir o app) — sem a variável, só as asserções rodam.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
// Carga direta das traduções no teste (sem o widget EasyLocalization) —
// Localization/Translations não saem pelo barrel do pacote.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/orders/data/datasource/order_datasource.dart';
import 'package:setes_web/app/modules/orders/domain/entity/order_entity.dart';
import 'package:setes_web/app/modules/orders/presentation/page/order_checks_dialog.dart';
import 'package:setes_web/app/modules/orders/presentation/page/order_negotiation_section.dart';

/// Só os lookups da negociação/cheque — o resto nunca é chamado aqui.
class _FakeDatasource implements OrderDatasource {
  @override
  Future<List<OrderPaymentTypeLookup>> paymentTypesLookup(String filter) async =>
      const [
        OrderPaymentTypeLookup(id: 6, description: 'Boleto', kind: 'B', maxParcels: 6),
        OrderPaymentTypeLookup(id: 3, description: 'Cheque', kind: 'Q', maxParcels: 3),
        OrderPaymentTypeLookup(id: 1, description: 'Dinheiro', kind: 'E', maxParcels: 1),
      ];

  @override
  Future<List<OrderBankLookup>> banksLookup(String filter) async => const [
        OrderBankLookup(id: 1, number: '001', description: 'Banco do Brasil'),
        OrderBankLookup(id: 10, number: '237', description: 'Bradesco'),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _boleto = OrderNegotiationBilling(
  paymentTypeId: 6,
  paymentTypeDescription: 'Boleto',
  paymentTypeKind: 'B',
  maxParcels: 6,
  deadline: '028/056',
  plots: 2,
);

OrderNegotiationParcel _parcel(int n, String due, double amount,
        {int typeId = 6, String desc = 'Boleto', String kind = 'B', bool own = false}) =>
    OrderNegotiationParcel(
      parcel: n,
      dueDate: due,
      amount: amount,
      paymentTypeId: typeId,
      paymentTypeDescription: desc,
      paymentTypeKind: kind,
      ownPaymentType: own,
    );

final _simple = OrderNegotiation(
  orderId: 41,
  status: 'A',
  mode: 'simple',
  billing: _boleto,
  base: const OrderNegotiationBase(itemsValue: 1200, freight: 50, base: 1250),
  preview: [
    _parcel(1, '2026-10-04', 625),
    _parcel(2, '2026-11-01', 625, typeId: 3, desc: 'Cheque pré-datado', kind: 'Q'),
  ],
);

final _elaborated = OrderNegotiation(
  orderId: 41,
  status: 'A',
  mode: 'elaborated',
  billing: _boleto,
  base: const OrderNegotiationBase(itemsValue: 1200, freight: 50, base: 1250),
  installments: [
    _parcel(1, '2026-10-04', 750),
    _parcel(2, '2026-11-01', 500, typeId: 3, desc: 'Cheque pré-datado', kind: 'Q', own: true),
  ],
  preview: [_parcel(1, '2026-10-04', 625), _parcel(2, '2026-11-01', 625)],
);

final _shotKey = GlobalKey();

Widget _wrap(Widget child) => RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SETES_SHOT_DIR'];
  if (dir == null || dir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required OrderNegotiation? negotiation,
  required void Function(OrderNegotiationInput input) onSave,
  bool busy = false,
}) async {
  tester.view.physicalSize = const Size(1000, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(OrderNegotiationSection(
    negotiation: negotiation,
    datasource: _FakeDatasource(),
    busy: busy,
    onSave: onSave,
    onReload: () {},
    // "Hoje" fixo: as fixtures (out/nov 2026) nunca viram "passado" com o
    // relógio real — o teste não depende do dia da execução.
    todayIso: '2026-09-07',
  )));
  await tester.pumpAndSettle();
}

/// byType casa o runtimeType EXATO (TextButton ≠ ButtonStyleButton) — o
/// predicate cobre Elevated/Outlined/TextButton do SetesButton.
Finder _button(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

bool _enabled(WidgetTester tester, String text) =>
    tester.widget<ButtonStyleButton>(_button(text)).enabled;

void main() {
  setUpAll(() async {
    // Textos REAIS do i18n pt (o .tr() resolve pela instância estática).
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync())
        as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
    // Fontes reais para os PNGs (sem elas o test renderiza blocos) — só
    // quando o cache do SDK existe na máquina; as asserções não dependem.
    const fontsDir = r'D:\flutter\bin\cache\artifacts\material_fonts';
    for (final (family, file) in const [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final font = File('$fontsDir\\$file');
      if (!font.existsSync()) continue;
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(font.readAsBytesSync().buffer)));
      await loader.load();
    }
  });

  testWidgets('via SIMPLES: preview somente leitura, Salvar manda sem installments',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _simple, onSave: (i) => saved = i);

    expect(find.text('forms.order.modeSimple'.tr()), findsOneWidget);
    expect(find.text('forms.order.negotiateParcels'.tr()), findsOneWidget);
    // Preview: 2 parcelas, a 2ª em cheque (selo).
    expect(find.text('04/10/2026 · R\$ 625,00'), findsOneWidget);
    expect(find.text('01/11/2026 · R\$ 625,00'), findsOneWidget);
    expect(find.text('forms.order.checkKind'.tr()), findsOneWidget);
    final baseRow = 'forms.order.baseRow'.tr(args: ['R\$ 1.250,00']);
    final maxRow = 'forms.order.maxParcelsRow'.tr(args: ['6']);
    expect(find.text('$baseRow · $maxRow'), findsOneWidget);
    await _shot(tester, 'negotiation_simple');

    // Troca só o prazo e salva: via simples = SEM installments.
    await tester.enterText(find.widgetWithText(TextFormField, '028/056'), '030/060/090');
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.paymentTypeId, 6);
    expect(saved!.deadline, '030/060/090');
    expect(saved!.installments, isNull);
    expect(saved!.toJson().containsKey('installments'), isFalse);
  });

  testWidgets('"Negociar parcelas" copia o preview; soma ≠ base bloqueia; nova linha fecha',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _simple, onSave: (i) => saved = i);

    await tester.tap(_button('forms.order.negotiateParcels'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.modeEditing'.tr()), findsOneWidget);
    expect(find.text('forms.order.backToDeadline'.tr()), findsOneWidget);
    // 2 linhas editáveis vindas do preview, soma = base → Salvar liberado.
    expect(find.widgetWithText(TextFormField, '625,00'), findsNWidgets(2));
    expect(find.text('forms.order.sumRow'.tr(args: ['R\$ 1.250,00'])), findsOneWidget);
    expect(_enabled(tester, 'forms.order.saveNegotiation'.tr()), isTrue);
    // Preview copiado: forma HERDADA (null) — mostra "Herda: Boleto".
    expect(find.text('forms.order.parcelInherits'.tr(args: ['Boleto'])), findsNWidgets(2));

    // Altera a 2ª parcela → soma 1.125 ≠ 1.250 → mensagem + Salvar travado.
    await tester.enterText(find.widgetWithText(TextFormField, '625,00').last, '500,00');
    await tester.pumpAndSettle();
    expect(find.text('forms.order.sumMismatch'.tr(args: ['R\$ 1.125,00', 'R\$ 1.250,00'])),
        findsOneWidget);
    expect(_enabled(tester, 'forms.order.saveNegotiation'.tr()), isFalse);
    await _shot(tester, 'negotiation_editing_mismatch');

    // "Adicionar parcela" sugere o que falta (125,00) → soma fecha.
    await tester.tap(_button('forms.order.addParcel'.tr()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '125,00'), findsOneWidget);
    expect(_enabled(tester, 'forms.order.saveNegotiation'.tr()), isTrue);
    await _shot(tester, 'negotiation_editing_ok');

    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    final rows = saved!.installments!;
    expect(rows.map((r) => r.parcel), [1, 2, 3]);
    expect(rows.map((r) => r.amount), [625, 500, 125]);
    // Nenhuma linha copiou o id do cabeçalho: herdar = null (M2).
    expect(rows.every((r) => r.paymentTypeId == null), isTrue);
    expect(rows.last.dueDate, '2026-12-01'); // última + 30 dias
  });

  testWidgets('ELABORADA gravada: só trocar o prazo devolve a grade inteira; Voltar ao prazo = sem installments',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _elaborated, onSave: (i) => saved = i);

    expect(find.text('forms.order.modeElaborated'.tr()), findsOneWidget);
    // Parcela 2 tem forma PRÓPRIA (Cheque) — a 1 herda.
    expect(find.text('forms.order.parcelInherits'.tr(args: ['Boleto'])), findsOneWidget);
    expect(find.text('Cheque pré-datado'), findsOneWidget);
    await _shot(tester, 'negotiation_elaborated');

    await tester.enterText(find.widgetWithText(TextFormField, '028/056'), '030');
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved!.deadline, '030');
    expect(saved!.installments, hasLength(2));
    expect(saved!.installments![0].paymentTypeId, isNull);
    expect(saved!.installments![1].paymentTypeId, 3);

    // Voltar ao prazo → decisão tipada → PUT sem installments.
    saved = null;
    await tester.tap(_button('forms.order.backToDeadline'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.confirmBackToDeadline'.tr()), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.backToDeadline'.tr()).last);
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.installments, isNull);
  });

  testWidgets('pedido FATURADO: somente leitura com a grade elaborada', (tester) async {
    final invoiced = OrderNegotiation(
      orderId: 41,
      status: 'F',
      mode: 'elaborated',
      billing: _boleto,
      base: _elaborated.base,
      installments: _elaborated.installments,
      preview: const [],
    );
    await _pumpSection(tester, negotiation: invoiced, onSave: (_) => fail('não salva'));
    expect(find.text('forms.order.saveNegotiation'.tr()), findsNothing);
    expect(find.text('forms.order.negotiateParcels'.tr()), findsNothing);
    expect(find.text('04/10/2026 · R\$ 750,00'), findsOneWidget);
    expect(find.text('01/11/2026 · R\$ 500,00'), findsOneWidget);
    await _shot(tester, 'negotiation_invoiced');
  });

  testWidgets('negociação indisponível oferece recarregar', (tester) async {
    await _pumpSection(tester, negotiation: null, onSave: (_) {});
    expect(find.text('forms.order.negotiationUnavailable'.tr()), findsOneWidget);
    expect(find.text('forms.order.reloadNegotiation'.tr()), findsOneWidget);
  });

  testWidgets('dialog de cheques: soma por parcela = parcela; devolve o bloco checks',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<OrderParcelChecksInput>? result;
    late BuildContext ctx;
    await tester.pumpWidget(_wrap(Builder(builder: (context) {
      ctx = context;
      return const SizedBox.shrink();
    })));
    final parcels = [
      _parcel(2, '2026-11-01', 500, typeId: 3, desc: 'Cheque pré-datado', kind: 'Q', own: true),
    ];
    final future = showOrderChecksDialog(ctx,
        parcels: parcels, datasource: _FakeDatasource());
    await tester.pumpAndSettle();
    expect(find.text('forms.order.checksTitle'.tr()), findsOneWidget);
    expect(find.text('forms.order.checkParcelHeader'.tr(args: ['2', '01/11/2026', 'R\$ 500,00'])),
        findsOneWidget);

    // Faturar sem cheque → pendência da parcela.
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.confirmInvoice'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.checksRequired'.tr(args: ['2'])), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();

    // Adicionar cheque: banco pelo lookup, campos, valor sugerido = 500,00.
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.addCheck'.tr()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '500,00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '01/11/2026'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('237 - Bradesco'));
    await tester.pumpAndSettle();
    // Achado do passeio nº 2: Salvar com Agência vazia marca o campo; ao
    // digitar, a marca some sem esperar o próximo Salvar.
    await tester.tap(find.widgetWithText(TextButton, 'register.save'.tr()));
    await tester.pumpAndSettle();
    final agencyRequired =
        'register.requiredField'.tr(args: ['forms.order.checkAgency'.tr()]);
    expect(find.text(agencyRequired), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(find.text(agencyRequired), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkAgency'.tr()), '1234');
    await tester.pumpAndSettle();
    expect(find.text(agencyRequired), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkAccount'.tr()), '56789-0');
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkNumber'.tr()), '000101');
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkIssuer'.tr()), 'Fulano de Tal');
    await tester.tap(find.text('forms.order.checkKindThird'.tr()));
    await tester.pumpAndSettle();
    await _shot(tester, 'checks_item_dialog');
    await tester.tap(find.widgetWithText(TextButton, 'register.save'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('forms.order.checkRowTitle'.tr(args: ['237 - Bradesco', '000101', 'R\$ 500,00'])),
        findsOneWidget);
    expect(find.text('forms.order.checksSumRow'.tr(args: ['R\$ 500,00', 'R\$ 500,00', 'R\$ 0,00'])),
        findsOneWidget);
    await _shot(tester, 'checks_dialog');

    await tester.tap(find.widgetWithText(TextButton, 'forms.order.confirmInvoice'.tr()));
    await tester.pumpAndSettle();
    result = await future;
    expect(result, hasLength(1));
    final check = result!.first.items.single;
    expect(result.first.parcel, 2);
    expect(check.bankId, 10);
    expect(check.kind, OrderCheckKind.third);
    expect(check.value, 500);
    expect(check.dtCheck, '2026-11-01');
  });

  // ------------------------------------------------------------------
  // Rodada 2 (2026-09-07): a tela consome `expected` e `deadlineValid`
  // ------------------------------------------------------------------

  testWidgets('prazo LEGADO (deadlineValid=false): aviso enquanto o texto não muda; salvar igual passa; prazo novo é estrito',
      (tester) async {
    OrderNegotiationInput? saved;
    final legacy = OrderNegotiation(
      orderId: 41,
      status: 'A',
      mode: 'simple',
      billing: const OrderNegotiationBilling(
        paymentTypeId: 6,
        paymentTypeDescription: 'Boleto',
        paymentTypeKind: 'B',
        maxParcels: 6,
        deadline: 'A VISTA',
        deadlineCanonical: null,
        deadlineValid: false,
        plots: 1,
      ),
      base: const OrderNegotiationBase(itemsValue: 100, freight: 0, base: 100),
      preview: [_parcel(1, '2026-09-07', 100)],
    );
    await _pumpSection(tester, negotiation: legacy, onSave: (i) => saved = i);
    expect(find.text('forms.order.deadlineLegacy'.tr(args: ['A VISTA'])), findsOneWidget);
    await _shot(tester, 'negotiation_legacy_deadline');

    // Sem mexer no prazo: o MESMO raw vai para a API (ela tolera — D-N4).
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved?.deadline, 'A VISTA');

    // Prazo NOVO com lixo → pendência LOCAL (nunca chega à API); o aviso some.
    saved = null;
    await tester.enterText(find.widgetWithText(TextFormField, 'A VISTA'), '30 DIAS');
    await tester.pumpAndSettle();
    expect(find.text('forms.order.deadlineLegacy'.tr(args: ['A VISTA'])), findsNothing);
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.deadlineInvalid'.tr()), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(saved, isNull);

    // Prazo novo válido (fora do canônico — a API normaliza) passa.
    await tester.enterText(find.widgetWithText(TextFormField, '30 DIAS'), '30/60');
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved?.deadline, '30/60');
  });

  testWidgets('prazo válido fora do canônico: "será gravado como"', (tester) async {
    final loose = OrderNegotiation(
      orderId: 41,
      status: 'A',
      mode: 'simple',
      billing: const OrderNegotiationBilling(
        paymentTypeId: 6,
        paymentTypeDescription: 'Boleto',
        paymentTypeKind: 'B',
        maxParcels: 6,
        deadline: '30/60',
        deadlineCanonical: '030/060',
        deadlineValid: true,
        plots: 2,
      ),
      base: const OrderNegotiationBase(itemsValue: 100, freight: 0, base: 100),
      preview: [_parcel(1, '2026-10-07', 50), _parcel(2, '2026-11-06', 50)],
    );
    await _pumpSection(tester, negotiation: loose, onSave: (_) {});
    expect(find.text('forms.order.deadlineCanonicalHint'.tr(args: ['030/060'])), findsOneWidget);
  });

  testWidgets('422 INSTALLMENT_MISMATCH com expected: base da tela atualizada e a decisão fecha a diferença na última parcela',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _elaborated, onSave: (i) => saved = i);
    final section = tester.state<OrderNegotiationSectionState>(
        find.byType(OrderNegotiationSection));

    // Servidor: itens mudaram fora da tela — base agora 1.300 (a tela tinha 1.250).
    final future = section.showServerFailure(const Failure(
      message: 'Valor do parcelamento não confere com o valor da ordem',
      statusCode: 422,
      code: 'INSTALLMENT_MISMATCH',
      fields: [
        FailureField(
          field: 'installments',
          message: 'Parcelamento 1250 difere do valor atual da ordem 1300',
          expected: 1300,
        ),
      ],
    ));
    await tester.pumpAndSettle();
    expect(
        find.text('forms.order.baseChanged'.tr(args: ['R\$ 1.300,00', 'R\$ 1.250,00'])),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.adjustLastParcel'.tr()));
    await tester.pumpAndSettle();
    await future;

    // Última parcela 500 → 550; cabeçalho e rodapé mostram a base NOVA
    // (o detalhe itens/frete velho some); Salvar liberado.
    expect(find.widgetWithText(TextFormField, '550,00'), findsOneWidget);
    expect(find.text('forms.order.baseCompareRow'.tr(args: ['R\$ 1.300,00'])), findsOneWidget);
    final newBaseRow = 'forms.order.baseRow'.tr(args: ['R\$ 1.300,00']);
    expect(find.text('$newBaseRow · ${'forms.order.maxParcelsRow'.tr(args: ['6'])}'),
        findsOneWidget);
    expect(find.text('forms.order.baseDetailRow'.tr(args: ['R\$ 1.200,00', 'R\$ 50,00'])),
        findsNothing);
    expect(_enabled(tester, 'forms.order.saveNegotiation'.tr()), isTrue);
    await _shot(tester, 'negotiation_base_adjusted');

    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved!.installments!.map((r) => r.amount), [750, 550]);
  });

  testWidgets('422 INSTALLMENT_MISMATCH: Cancelar mantém a base nova e o Salvar travado',
      (tester) async {
    await _pumpSection(tester, negotiation: _elaborated, onSave: (_) => fail('não salva'));
    final section = tester.state<OrderNegotiationSectionState>(
        find.byType(OrderNegotiationSection));
    final future = section.showServerFailure(const Failure(
      message: 'x',
      statusCode: 422,
      code: 'INSTALLMENT_MISMATCH',
      fields: [FailureField(field: 'installments', message: 'x', expected: 1300)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'register.cancel'.tr()));
    await tester.pumpAndSettle();
    await future;
    expect(find.text('forms.order.sumMismatch'.tr(args: ['R\$ 1.250,00', 'R\$ 1.300,00'])),
        findsOneWidget);
    expect(_enabled(tester, 'forms.order.saveNegotiation'.tr()), isFalse);
  });

  testWidgets('422 MAX_PARCELS_EXCEEDED no prazo: expected vira o limite exibido e validado localmente',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _simple, onSave: (i) => saved = i);
    final section = tester.state<OrderNegotiationSectionState>(
        find.byType(OrderNegotiationSection));
    final future = section.showServerFailure(const Failure(
      message: 'Número de parcelas passa do limite da forma de pagamento',
      statusCode: 422,
      code: 'MAX_PARCELS_EXCEEDED',
      fields: [
        FailureField(
          field: 'deadline',
          message: '2 parcelas; a forma "Boleto" permite 1',
          expected: 1,
        ),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('2 parcelas; a forma "Boleto" permite 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    await future;
    final baseRow = 'forms.order.baseRow'.tr(args: ['R\$ 1.250,00']);
    expect(find.text('$baseRow · ${'forms.order.maxParcelsRow'.tr(args: ['1'])}'),
        findsOneWidget);

    // O limite agora é local: prazo com 2 parcelas não sai da tela.
    await tester.enterText(find.widgetWithText(TextFormField, '028/056'), '030/060');
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.maxParcelsExceeded'.tr(args: ['1'])), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(saved, isNull);
  });

  testWidgets('marca da pendência local some ao corrigir o campo e não sobrevive ao Salvar (achado do passeio nº 2)',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _elaborated, onSave: (i) => saved = i);

    // Data inválida (a soma segue fechando, então o Salvar está liberado)
    // → pendência local → OK deixa a marca no campo.
    await tester.enterText(find.widgetWithText(TextFormField, '04/10/2026'), '99/99');
    await tester.pumpAndSettle();
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('register.invalidDate'.tr()), findsOneWidget);

    // Corrigiu → a marca some na hora (sem esperar o próximo Salvar).
    await tester.enterText(find.widgetWithText(TextFormField, '99/99'), '04/10/2026');
    await tester.pumpAndSettle();
    expect(find.text('register.invalidDate'.tr()), findsNothing);

    // Mesmo no prazo (via simples): marca → corrige → some; Salvar segue.
    saved = null;
    await _pumpSection(tester, negotiation: _simple, onSave: (i) => saved = i);
    await tester.enterText(
        find.widgetWithText(TextFormField, _simple.billing!.deadline!), '30 DIAS');
    await tester.pumpAndSettle();
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.deadlineInvalid'.tr()), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '30 DIAS'), '30/60');
    await tester.pumpAndSettle();
    expect(find.text('forms.order.deadlineInvalid'.tr()), findsNothing);
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    // A tela manda o texto digitado; quem canoniza (030/060) é a API.
    expect(saved!.deadline, '30/60');
  });

  testWidgets('D-N6 vencimento no passado: selo na linha, contagem no rodapé e decisão ao salvar (aceita, nunca bloqueia)',
      (tester) async {
    OrderNegotiationInput? saved;
    await _pumpSection(tester, negotiation: _elaborated, onSave: (i) => saved = i);
    expect(find.text('forms.order.dueDatePast'.tr()), findsNothing);

    // 1ª parcela passa a vencer ANTES de hoje (07/09/2026): sinal já recebido.
    await tester.enterText(find.widgetWithText(TextFormField, '04/10/2026'), '01/09/2026');
    await tester.pumpAndSettle();
    expect(find.text('forms.order.dueDatePast'.tr()), findsOneWidget);
    expect(find.text('forms.order.pastDueDatesRow'.tr(args: ['1'])), findsOneWidget);
    // Aviso, não bloqueio: Salvar continua liberado.
    expect(_enabled(tester, 'forms.order.saveNegotiation'.tr()), isTrue);
    await _shot(tester, 'negotiation_past_due');

    // Salvar → decisão tipada; Cancelar volta à grade sem gravar.
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.confirmPastDueDates'.tr(args: ['1'])), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'register.cancel'.tr()));
    await tester.pumpAndSettle();
    expect(saved, isNull);

    // "Salvar assim" grava o vencimento retroativo (a API aceita — D-N6).
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.saveAnyway'.tr()));
    await tester.pumpAndSettle();
    expect(saved!.installments!.first.dueDate, '2026-09-01');
    expect(saved!.installments!.last.dueDate, '2026-11-01');

    // Vencimento HOJE não é passado.
    saved = null;
    await tester.enterText(find.widgetWithText(TextFormField, '01/09/2026'), '07/09/2026');
    await tester.pumpAndSettle();
    expect(find.text('forms.order.dueDatePast'.tr()), findsNothing);
    await tester.tap(_button('forms.order.saveNegotiation'.tr()));
    await tester.pumpAndSettle();
    expect(saved!.installments!.first.dueDate, '2026-09-07');
  });

  testWidgets('dialog de cheques com expected (D7): a soma fecha contra o valor da NOTA, não o negociado',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext ctx;
    await tester.pumpWidget(_wrap(Builder(builder: (context) {
      ctx = context;
      return const SizedBox.shrink();
    })));
    final parcels = [
      _parcel(1, '2026-10-04', 500, typeId: 3, desc: 'Cheque pré-datado', kind: 'Q', own: true),
    ];
    // Reabertura após o 422: cheque de 500 digitado; a nota exige 520 na 1ª.
    const typed = OrderCheckInput(
      bankId: 10,
      bankLabel: '237 - Bradesco',
      agency: '1234',
      account: '56789-0',
      number: '000101',
      issuer: 'Fulano de Tal',
      value: 500,
      dtCheck: '2026-10-04',
    );
    final future = showOrderChecksDialog(
      ctx,
      parcels: parcels,
      datasource: _FakeDatasource(),
      initial: const [OrderParcelChecksInput(parcel: 1, items: [typed])],
      expectedAmounts: const {1: 520},
      hint: 'Soma dos cheques 500 difere do valor da parcela 520',
    );
    await tester.pumpAndSettle();
    expect(find.text('forms.order.checkParcelTarget'.tr(args: ['R\$ 520,00', 'R\$ 500,00'])),
        findsOneWidget);
    expect(find.text('forms.order.checksSumRow'.tr(args: ['R\$ 500,00', 'R\$ 520,00', '-R\$ 20,00'])),
        findsOneWidget);
    await _shot(tester, 'checks_dialog_expected');

    // Confirmar sem fechar → pendência contra o valor da NOTA.
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.confirmInvoice'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.checksSumMismatch'.tr(args: ['1', 'R\$ 500,00', 'R\$ 520,00'])),
        findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'register.ok'.tr()));
    await tester.pumpAndSettle();

    // Adicionar cheque: sugere o que FALTA contra 520 (20,00).
    await tester.tap(find.widgetWithText(TextButton, 'forms.order.addCheck'.tr()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '20,00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('001 - Banco do Brasil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkAgency'.tr()), '1');
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkAccount'.tr()), '2');
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkNumber'.tr()), '3');
    await tester.enterText(find.widgetWithText(TextFormField, 'forms.order.checkIssuer'.tr()), 'Beltrano');
    await tester.tap(find.widgetWithText(TextButton, 'register.save'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('forms.order.checksSumRow'.tr(args: ['R\$ 520,00', 'R\$ 520,00', 'R\$ 0,00'])),
        findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'forms.order.confirmInvoice'.tr()));
    await tester.pumpAndSettle();
    final result = await future;
    expect(result!.single.parcel, 1);
    expect(result.single.items.map((c) => c.value), [500, 20]);
  });
}
