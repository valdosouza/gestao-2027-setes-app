// Seção "No fisco" da OS faturada — F2b (D-F139/D-F140/D-F142). O que este
// teste fixa na TELA:
// (1) DUAS fontes, DUAS falhas: a voz indisponível (nfse-api) e o efeito
//     indisponível (ERP) são ditos cada um pelo que é — nunca "nada pendente"
//     — e uma falha não esconde a outra fonte;
// (2) os botões vêm do `state` do servidor, do `effect` do ERP e do
//     privilégio — nunca de coluna crua: Transmitir só nos estados
//     transmissíveis e com TRANSMITIR; "Cancelar nota" (D-F150 — rótulo neutro) na autorizada e com
//     CANCELAR; "Aplicar o cancelamento na nota" só no efeito `apply`;
//     "Manter a nota" só no `decide`;
// (3) todo cancelamento pede o MESMO fluxo (o plano — D-F140): os três botões
//     de cancelamento chamam o mesmo callback;
// (4) nota cancelada é documento encerrado — nenhuma ação de mudança.

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
// Carga direta das traduções no teste (sem o widget EasyLocalization) —
// mesmo recurso do service_order_keep_invoice_dialog_test.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_widgets/setes_widgets.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/widget/service_order_fiscal_section.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

const _invoiced = ServiceOrderFull(id: 7374, customerId: 1, status: 'F');
const _cancelledOrder = ServiceOrderFull(id: 7374, customerId: 1, status: 'C');

const _authorized = ServiceOrderFiscalView(
  state: NfseState.authorized,
  currentAttempt: 1,
  transmissions: [
    ServiceOrderFiscalTransmission(attempt: 1, environment: 'P', lastKind: 'A', accessKey: '41069021234567800019900001000000000704', nfseNumber: '704'),
  ],
  xmlAvailable: true,
  danfseAvailable: true,
);

MenuInterface _iface(List<String> privileges) =>
    MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

/// Registra quem a seção chamou.
class _Calls {
  final list = <String>[];
}

Future<_Calls> _pump(WidgetTester tester, ServiceOrderDetailState state, {bool settle = true}) async {
  final calls = _Calls();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ServiceOrderFiscalSection(
          state: state,
          onTransmit: () => calls.list.add('transmit'),
          onFiscalRefresh: () => calls.list.add('refresh'),
          onFiscalXml: () => calls.list.add('xml'),
          onFiscalDanfse: () => calls.list.add('danfse'),
          onCancelInvoice: () => calls.list.add('cancel-flow'),
          onKeepInvoice: () => calls.list.add('keep'),
        ),
      ),
    ),
  ));
  // busy: o spinner do botão anima para sempre — sem settle
  settle ? await tester.pumpAndSettle() : await tester.pump();
  return calls;
}

void main() {
  setUpAll(() {
    Localization.load(const Locale('pt'), translations: Translations(_load('pt')));
  });

  setUp(() => CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR']));
  tearDown(() => CurrentInterface.value = null);

  group('duas fontes, duas falhas', () {
    testWidgets('voz indisponível: dita como tal, sem botões de ação; o efeito do ERP segue aparecendo', (tester) async {
      await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply),
      ));

      expect(find.text('Situação fiscal indisponível: Fisco indisponível'), findsOneWidget);
      expect(find.text('O fisco cancelou a NFS-e — falta cancelar a nota no sistema.'), findsOneWidget);
      expect(find.text('Transmitir'), findsNothing);
      expect(find.text('Consultar'), findsNothing);
    });

    testWidgets('efeito indisponível: dito como tal (nunca "nada pendente"); a voz segue com os botões dela', (tester) async {
      await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: _authorized,
        effectFailure: Failure(message: 'Situação no fisco indisponível', statusCode: 503, code: 'FISCAL_VOICE_UNAVAILABLE'),
      ));

      expect(find.text('Efeito na nota indisponível: Situação no fisco indisponível'), findsOneWidget);
      expect(find.text('Consultar'), findsOneWidget);
      expect(find.text('Cancelar nota'), findsOneWidget);
    });
  });

  group('botões pelo estado do servidor, pelo efeito e pelo privilégio', () {
    testWidgets('nunca transmitida: frase própria + Transmitir; sem tentativa não há Consultar', (tester) async {
      final calls = await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: ServiceOrderFiscalView(),
        effect: ServiceOrderFiscalEffect(),
      ));

      expect(find.text('NFS-e ainda não transmitida ao fisco'), findsOneWidget);
      expect(find.text('Consultar'), findsNothing);
      await tester.tap(find.text('Transmitir'));
      expect(calls.list, ['transmit']);
    });

    testWidgets('sem o privilégio TRANSMITIR: o botão não aparece (a API recusaria)', (tester) async {
      CurrentInterface.value = _iface(['CANCELAR']);
      await _pump(tester, const ServiceOrderDetailState(order: _invoiced, fiscal: ServiceOrderFiscalView()));

      expect(find.text('Transmitir'), findsNothing);
    });

    testWidgets('autorizada: chave/nº da vigente, Consultar/XML/DANFSe e "Cancelar nota" pede o PLANO', (tester) async {
      final calls = await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: _authorized,
        effect: ServiceOrderFiscalEffect(),
      ));

      expect(find.text('Transmitir'), findsNothing, reason: 'autorizada não é transmissível');
      expect(find.text('41069021234567800019900001000000000704'), findsOneWidget);
      for (final label in ['Consultar', 'XML', 'DANFSe', 'Cancelar nota']) {
        await tester.tap(find.text(label));
      }
      expect(calls.list, ['refresh', 'xml', 'danfse', 'cancel-flow']);
    });

    testWidgets('autorizada sem o privilégio CANCELAR: sem "Cancelar nota"; sem TRANSMITIR: sem "Consultar" (a nfse-api exige — F2B-SOC-11)', (tester) async {
      CurrentInterface.value = _iface(['TRANSMITIR']);
      await _pump(tester, const ServiceOrderDetailState(order: _invoiced, fiscal: _authorized));

      expect(find.text('Cancelar nota'), findsNothing);
      expect(find.text('Consultar'), findsOneWidget);

      CurrentInterface.value = _iface(['CANCELAR']);
      await _pump(tester, const ServiceOrderDetailState(order: _invoiced, fiscal: _authorized));
      expect(find.text('Consultar'), findsNothing);
      expect(find.text('Cancelar nota'), findsOneWidget);
    });

    testWidgets('F2B-SOC-11: voz indisponível NÃO esconde "Aplicar o cancelamento na nota" (só depende do efeito do ERP); a falha mostra o código de suporte (F2B-SOC-10)', (tester) async {
      final calls = await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503, supportRef: 'REF-77'),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply),
      ));

      expect(find.textContaining('REF-77'), findsOneWidget);
      await tester.tap(find.text('Aplicar o cancelamento na nota'));
      expect(calls.list, ['cancel-flow']);
    });

    testWidgets('rejeitada (R): cabe transmitir de novo', (tester) async {
      await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1, transmissions: [
          ServiceOrderFiscalTransmission(attempt: 1, lastKind: 'R', lastCode: 'E0116', lastMessage: 'IM obrigatória'),
        ]),
      ));

      expect(find.text('Transmitir'), findsOneWidget);
      expect(find.text('Cancelar nota'), findsNothing);
    });

    testWidgets('efeito apply: a frase + "Aplicar o cancelamento na nota" pede o MESMO fluxo do plano', (tester) async {
      final calls = await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: ServiceOrderFiscalView(state: NfseState.cancelled, currentAttempt: 1, localCancelPending: true),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply),
      ));

      expect(find.text('O fisco cancelou a NFS-e — falta cancelar a nota no sistema.'), findsOneWidget);
      await tester.tap(find.text('Aplicar o cancelamento na nota'));
      expect(calls.list, ['cancel-flow']);
      expect(find.text('Cancelar nota'), findsNothing);
    });

    testWidgets('efeito cancel (de ofício / homologação): "Cancelar nota" pelo plano', (tester) async {
      final calls = await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: ServiceOrderFiscalView(state: NfseState.cancelled, currentAttempt: 1),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.cancel),
      ));

      await tester.tap(find.text('Cancelar nota'));
      expect(calls.list, ['cancel-flow']);
    });

    testWidgets('efeito decide (substituída, sem decisão): aviso + chave da substituta + "Manter a nota"', (tester) async {
      final calls = await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: ServiceOrderFiscalView(
          state: NfseState.cancelled,
          currentAttempt: 1,
          substitution: ServiceOrderFiscalSubstitution(substituteAccessKey: 'SUBSTITUTA-123'),
        ),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));

      expect(find.textContaining('a nota fica viva no ERP até você decidir'), findsOneWidget);
      // D-F159: com o bloco da VOZ, a linha do ERP não se repete (uma frase da substituição só)
      expect(find.textContaining('SUBSTITUÍDA'), findsOneWidget);
      expect(find.text('SUBSTITUTA-123'), findsOneWidget);
      await tester.tap(find.text('Manter a nota'));
      expect(calls.list, ['keep']);
    });

    testWidgets('decisão já tomada (ERP diz none + a dispensa): frase de decidida + motivo, sem "Manter a nota"', (tester) async {
      await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        fiscal: ServiceOrderFiscalView(
          state: NfseState.cancelled,
          currentAttempt: 1,
          substitution: ServiceOrderFiscalSubstitution(substituteAccessKey: 'SUBSTITUTA-123'),
        ),
        effect: ServiceOrderFiscalEffect(
          cancelWaiver: ServiceOrderFiscalCancelWaiver(accessKey: 'K1', reason: 'Substituta no portal'),
        ),
      ));

      expect(find.textContaining('a decisão sobre a nota já foi registrada'), findsOneWidget);
      expect(find.textContaining('motivo: Substituta no portal'), findsOneWidget);
      expect(find.text('Manter a nota'), findsNothing);
    });

    testWidgets('busy: todos os botões desabilitados (nada duplo no fisco)', (tester) async {
      await _pump(tester, const ServiceOrderDetailState(
        order: _invoiced,
        saving: true,
        fiscal: _authorized,
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply),
      ), settle: false);

      final buttons = tester.widgetList<SetesButton>(find.byType(SetesButton)).toList();
      expect(buttons, isNotEmpty);
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });
  });

  testWidgets('nota CANCELADA: documento encerrado — nenhuma ação de mudança, só leitura', (tester) async {
    await _pump(tester, const ServiceOrderDetailState(
      order: _cancelledOrder,
      fiscal: ServiceOrderFiscalView(state: NfseState.failed, currentAttempt: 1, xmlAvailable: true),
      effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply),
    ));

    for (final label in ['Transmitir', 'Cancelar nota', 'Aplicar o cancelamento na nota', 'Cancelar nota', 'Manter a nota']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('O fisco cancelou a NFS-e — falta cancelar a nota no sistema.'), findsNothing);
    expect(find.text('Consultar'), findsOneWidget);
    expect(find.text('XML'), findsOneWidget);
  });
}
