// Fase IBS/CBS, IB-3 no app (prompt_fase_ibs_cbs.md §13 — D-IB75/D-IB76): o app só RENDERIZA a declaração IBS/CBS que as APIs devolvem.
// O que este teste fixa:
// (1) o parse das quatro formas (resultado do faturamento, prévia, congelada, enviada + valores do fisco) tolera ausência/lixo — API
//     anterior = null, nunca exceção;
// (2) o relatório do lote RECONTA "faturadas sem IBS/CBS" das linhas (a fonte é uma — D27), também na agregação dos blocos;
// (3) os motivos da omissão são a lista FECHADA da API, traduzida em pt e en (motivo desconhecido aparece cru);
// (4) o cartão mostra o que veio e nada decide; os valores do fisco são texto decimal exato formatado pela peça de moeda.

import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/orders/domain/entity/order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/shared/ibscbs/ibscbs.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

/// D-IB91 (gates da IB-3): a lista FECHADA de motivos é PUBLICADA pela API (`IBSCBS_OMISSIONS` em @shared/ibscbs-classification) — o teste
/// lê a constante do setes-api irmão (worktree ou árvore principal: `../../../setes-api`; `SETES_API_DIR` sobrepõe) e confere o espelho do
/// app ([kIbscbsOmissions]) e as chaves i18n contra ELA. Motivo novo na API = este teste vermelho até o app ganhar o texto.
List<String> _apiOmissions() {
  final dir = Platform.environment['SETES_API_DIR'] ?? '../../../setes-api';
  final src = File('$dir/src/shared/ibscbs-classification/index.ts');
  expect(src.existsSync(), isTrue, reason: 'setes-api irmão não encontrado em $dir (defina SETES_API_DIR)');
  final block = RegExp(r'IBSCBS_OMISSIONS = Object\.freeze\(\[([\s\S]*?)\]').firstMatch(src.readAsStringSync());
  expect(block, isNotNull, reason: 'IBSCBS_OMISSIONS não encontrada na API');
  return RegExp(r"'([a-z-]+)'").allMatches(block!.group(1)!).map((m) => m.group(1)!).toList();
}

void main() {
  setUpAll(() {
    Localization.load(const Locale('pt'), translations: Translations(_load('pt')));
  });

  group('parse — API anterior ou bloco ausente = null, nunca exceção', () {
    test('resultado do faturamento da OS e linha do lote', () {
      final r = ServiceOrderInvoiceResult.fromJson({
        'invoiceNumber': 7001, 'ibscbs': {'declared': false, 'omitted': ['not-classified', 'nbs-missing']},
      });
      expect(r.ibscbs, const IbscbsOutcome(declared: false, omitted: ['not-classified', 'nbs-missing']));
      expect(ServiceOrderInvoiceResult.fromJson({'invoiceNumber': 1}).ibscbs, isNull);
      expect(ServiceOrderInvoiceResult.fromJson({'invoiceNumber': 1, 'ibscbs': 'lixo'}).ibscbs, isNull);
    });

    test('prévia: aviso antes da obrigação × recusa depois (o mesmo texto do 422)', () {
      final aviso = IbscbsPreview.fromJson({
        'competenceDate': '2026-12-20', 'obligationStart': '2027-01-01', 'obligatory': false,
        'declared': false, 'omitted': ['not-classified'], 'refusal': null,
      })!;
      expect(aviso.refused, isFalse);
      expect(aviso.obligatory, isFalse);
      expect(aviso.atObligation, isNull);                       // API sem o campo (anterior à D-IB89) = sem 2º veredito
      final comAhead = IbscbsPreview.fromJson({
        'competenceDate': '2026-12-20', 'obligationStart': '2027-01-01', 'obligatory': false, 'declared': false, 'omitted': ['nbs-missing'],
        'atObligation': {'declared': false, 'omitted': ['nbs-missing'], 'refusal': {'code': 'X', 'message': 'recusada'}},
      })!;
      expect(comAhead.atObligation?.refused, isTrue);
      expect(IbscbsOrderView.fromJson({'preview': null, 'frozen': null, 'unavailable': true})?.unavailable, isTrue);
      final recusa = IbscbsPreview.fromJson({
        'competenceDate': '2027-01-05', 'obligationStart': '2027-01-01', 'obligatory': true, 'declared': false,
        'omitted': ['not-classified'],
        'refusal': {'code': 'INVOICE_SERVICE_IBSCBS_REQUIRED', 'message': 'Declaração IBS/CBS obrigatória desde 2027-01-01'},
      })!;
      expect(recusa.refused, isTrue);
      expect(recusa.refusalCode, 'INVOICE_SERVICE_IBSCBS_REQUIRED');
      expect(IbscbsPreview.fromJson(null), isNull);
    });

    test('OS completa: prevista (aberta) e congelada (faturada)', () {
      final aberta = ServiceOrderFull.fromJson({
        'id': 1, 'customerId': 2, 'status': 'A',
        'ibscbs': {'preview': {'competenceDate': '2026-12-20', 'obligationStart': '2027-01-01', 'declared': true, 'omitted': []}, 'frozen': null},
      });
      expect(aberta.ibscbs?.preview?.declared, isTrue);
      expect(aberta.ibscbs?.frozen, isNull);
      final faturada = ServiceOrderFull.fromJson({
        'id': 1, 'customerId': 2, 'status': 'F',
        'ibscbs': {'preview': null, 'frozen': {'classificationCode': '000001', 'placeIndicatorCode': '100301', 'nbs': '115021000'}},
      });
      expect(faturada.ibscbs?.frozen?.hasGroup, isTrue);
      expect(ServiceOrderFull.fromJson({'id': 1, 'customerId': 2}).ibscbs, isNull);
    });

    test('visão fiscal (nfse-api): enviada + valores em TEXTO exato; partes ausentes = null', () {
      final v = ServiceOrderFiscalView.fromJson({
        'state': 'authorized',
        'ibscbs': {
          'declared': {'cst': '000', 'classificationCode': '000001', 'placeIndicatorCode': '100301', 'nbs': '115021000'},
          'values': {'totalInvoiceValue': '250.00', 'ibsTotalValue': '0.25', 'cbsValue': '2.25'},
        },
      });
      expect(v.ibscbs?.hasDeclared, isTrue);
      expect(v.ibscbs?.cbsValue, '2.25');
      expect(v.ibscbs?.groupInDps, isNull);                     // nfse-api anterior à D-IB90 = sem a informação
      final semGrupo = ServiceOrderFiscalView.fromJson({'state': 'authorized', 'ibscbs': {'declared': null, 'groupInDps': false, 'values': null}});
      expect(semGrupo.ibscbs?.groupInDps, isFalse);
      final semValores = ServiceOrderFiscalView.fromJson({'state': 'authorized', 'ibscbs': {'declared': null, 'values': null}});
      expect(semValores.ibscbs?.hasDeclared, isFalse);
      expect(semValores.ibscbs?.hasValues, isFalse);
      expect(ServiceOrderFiscalView.fromJson({'state': 'none'}).ibscbs, isNull);
    });

    test('pedido de venda: prévia no validate e resultado no faturamento', () {
      final v = OrderBillingValidation.fromJson({
        'orderId': 9, 'issues': [],
        'ibscbs': {'competenceDate': '2026-12-20', 'obligationStart': '2027-01-01', 'declared': false, 'omitted': ['nbs-missing']},
      });
      expect(v.canInvoice, isTrue); // o aviso nunca bloqueia
      expect(v.ibscbs?.omitted, ['nbs-missing']);
      final i = OrderBillingInvoice.fromJson({'orderId': 9, 'ibscbs': {'declared': true, 'omitted': []}});
      expect(i.ibscbs?.declared, isTrue);
      expect(OrderBillingInvoice.fromJson({'orderId': 9}).ibscbs, isNull);
    });
  });

  group('relatório do lote — "sem IBS/CBS" recontado das LINHAS (D27)', () {
    const comGrupo = BatchInvoiceEntry(orderId: 1, ok: true, ibscbs: IbscbsOutcome(declared: true));
    const semGrupo = BatchInvoiceEntry(orderId: 2, ok: true, ibscbs: IbscbsOutcome(declared: false, omitted: ['not-classified']));
    const semInfo = BatchInvoiceEntry(orderId: 3, ok: true);
    const recusada = BatchInvoiceEntry(orderId: 4, ok: false, error: 'x', ibscbs: IbscbsOutcome(declared: false));
    const interrompida = BatchInvoiceEntry.aborted(orderId: 5, error: 'sem conexão');

    test('conta só faturadas; recusada e interrompida nunca entram; sem bloco = não conta', () {
      final r = BatchInvoiceReport.fromEntries(const [comGrupo, semGrupo, semInfo, recusada, interrompida]);
      expect(r.ibscbsDeclared, 1);
      expect(r.ibscbsOmitted, 1);
      expect(semGrupo.ibscbsOmitted, isTrue);
      expect(recusada.ibscbsOmitted, isFalse);
      expect(interrompida.ibscbs, isNull);
    });

    test('a agregação dos blocos reconta (nunca soma os contadores parciais)', () {
      final a = BatchInvoiceReport.fromJson({
        'ibscbsDeclared': 99, 'ibscbsOmitted': 99,   // contador parcial errado: a agregação não confia nele
        'results': [
          {'orderId': 1, 'ok': true, 'ibscbs': {'declared': false, 'omitted': ['nbs-missing']}},
        ],
      });
      final b = BatchInvoiceReport.fromEntries(const [comGrupo, semGrupo]);
      final merged = BatchInvoiceReport.merge([a, b]);
      expect(merged.ibscbsOmitted, 2);
      expect(merged.ibscbsDeclared, 1);
    });
  });

  group('motivos — lista FECHADA da API traduzida', () {
    test('D-IB91: o espelho do app = a lista PUBLICADA pela API, e todo motivo tem texto em pt e en', () {
      final api = _apiOmissions();
      expect(api, hasLength(8));
      expect(kIbscbsOmissions.toSet(), api.toSet());
      for (final lang in ['pt', 'en']) {
        final omitted = (_load(lang)['ibscbs'] as Map<String, dynamic>)['omitted'] as Map<String, dynamic>;
        expect(omitted.keys.toSet(), api.toSet(), reason: lang);
      }
    });

    test('conhecido = texto; desconhecido = cru (API mais nova que o build)', () {
      expect(ibscbsOmissionText('nbs-missing'), 'serviço sem NBS');
      expect(ibscbsOmissionText('motivo-novo'), 'motivo-novo');
    });

    test('valor do fisco: formatado do TEXTO (exato no domínio inteiro do TSDec15V2); ausente/fora da forma = travessão', () {
      expect(ibscbsMoney('1234.50'), 'R\$ 1.234,50');
      expect(ibscbsMoney('0'), 'R\$ 0,00');
      expect(ibscbsMoney('2.5'), 'R\$ 2,50');
      expect(ibscbsMoney('999999999999999.99'), 'R\$ 999.999.999.999.999,99');
      expect(ibscbsMoney(null), '—');
      for (final bad in ['NaN', 'Infinity', '-1.00', '1e3', '', '01.00']) {
        expect(ibscbsMoney(bad), '—', reason: bad);
      }
    });
  });

  group('cartão IBS/CBS — só renderiza', () {
    Future<void> pump(WidgetTester tester, Widget card) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));

    testWidgets('nada a mostrar = nada na tela', (tester) async {
      await pump(tester, const IbscbsCard());
      expect(find.text('IBS / CBS'), findsNothing);
    });

    testWidgets('prévia em AVISO: a data da prévia, a nota sairia sem o grupo (data da obrigação + motivo) e o veredito NA OBRIGAÇÃO (D-IB89)',
        (tester) async {
      await pump(tester, const IbscbsCard(preview: IbscbsPreview(
        competenceDate: '2026-12-20', obligationStart: '2027-01-01', obligatory: false,
        today: IbscbsVerdict(declared: false, omitted: ['not-classified']),
        atObligation: IbscbsVerdict(declared: false, omitted: ['not-classified'],
            refusalCode: 'INVOICE_SERVICE_IBSCBS_REQUIRED', refusalMessage: 'Declaração obrigatória: Suporte mensal'))));
      expect(find.text('IBS / CBS'), findsOneWidget);
      expect(find.text('Prévia para faturar em 20/12/2026:'), findsOneWidget);
      expect(find.textContaining('SEM o grupo IBS/CBS — obrigatório a partir de 01/01/2027. Motivo: serviço sem classificação IBS/CBS'),
          findsOneWidget);
      expect(find.text('A partir de 01/01/2027 o faturamento será RECUSADO: Declaração obrigatória: Suporte mensal'), findsOneWidget);
    });

    testWidgets('prévia RECUSADA: a mensagem da API, sem reescrever; depois da obrigação não há 2º veredito', (tester) async {
      await pump(tester, const IbscbsCard(preview: IbscbsPreview(
        competenceDate: '2027-01-05', obligationStart: '2027-01-01', obligatory: true,
        today: IbscbsVerdict(declared: false,
            refusalCode: 'INVOICE_SERVICE_IBSCBS_REQUIRED', refusalMessage: 'Declaração obrigatória: Suporte mensal'))));
      expect(find.text('Declaração obrigatória: Suporte mensal'), findsOneWidget);
      expect(find.byKey(const Key('ibscbs-at-obligation')), findsNothing);
    });

    testWidgets('D-IB87: leitura indisponível no servidor = dita como tal (o resto da OS segue)', (tester) async {
      await pump(tester, const IbscbsCard(unavailable: true));
      expect(find.byKey(const Key('ibscbs-unavailable')), findsOneWidget);
    });

    testWidgets('D-IB90: congelada COM o grupo × NFS-e autorizada SEM o grupo = alerta; XML indisponível (null) não alerta', (tester) async {
      const frozen = IbscbsFrozen(classificationCode: '000001', placeIndicatorCode: '100301', nbs: '115021000');
      await pump(tester, const IbscbsCard(frozen: frozen, fiscal: IbscbsFiscal(groupInDps: false)));
      expect(find.text('Atenção: a NFS-e autorizada NÃO leva o grupo IBS/CBS que a nota congelou.'), findsOneWidget);
      await pump(tester, const IbscbsCard(frozen: frozen, fiscal: IbscbsFiscal()));
      expect(find.byKey(const Key('ibscbs-sent-without-group')), findsNothing);
    });

    testWidgets('faturada: congelada + enviada + valores do fisco', (tester) async {
      await pump(tester, const IbscbsCard(
        frozen: IbscbsFrozen(classificationCode: '000001', placeIndicatorCode: '100301', nbs: '115021000'),
        fiscal: IbscbsFiscal(cst: '000', classificationCode: '000001', placeIndicatorCode: '100301', nbs: '115021000',
            totalInvoiceValue: '250.00', ibsTotalValue: '0.25', cbsValue: '2.25'),
      ));
      expect(find.text('Declaração na nota: cClassTrib 000001 · cIndOp 100301 · NBS 115021000'), findsOneWidget);
      expect(find.text('Enviado ao fisco: CST 000 · cClassTrib 000001 · cIndOp 100301 · NBS 115021000'), findsOneWidget);
      expect(find.text('Calculado pelo fisco: IBS R\$ 0,25 · CBS R\$ 2,25 · total da nota R\$ 250,00'), findsOneWidget);
    });

    testWidgets('enviada sem os valores lidos: dito como pendente (nunca zero)', (tester) async {
      await pump(tester, const IbscbsCard(fiscal: IbscbsFiscal(cst: '000', classificationCode: '000001', placeIndicatorCode: '100301')));
      expect(find.byKey(const Key('ibscbs-values-pending')), findsOneWidget);
      expect(find.textContaining('R\$ 0,00'), findsNothing);
    });

    testWidgets('faturada sem o grupo: dita como tal', (tester) async {
      await pump(tester, const IbscbsCard(frozen: IbscbsFrozen(nbs: '115021000')));
      expect(find.text('A nota saiu sem o grupo IBS/CBS (NBS 115021000).'), findsOneWidget);
    });
  });
}
