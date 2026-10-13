// GATE ADVERSARIAL do DELTA da Rodada 6 da F2a/F2b (setes-app) — alvo: commit
// 3b5b2b6 (delta sobre 6d94a6d): D-F159 (voz do fisco fora + efeito `decide` =
// a linha do ERP junto do "Manter a nota"), D-F160 (só o `onDispose` do MÓDULO
// para os lotes — o `dispose` da página saiu) e D-F163 (409 RESOURCE_BUSY num
// ATO = desfecho desconhecido).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R6-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r6_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
// Carga direta das traduções no teste (sem o widget EasyLocalization) — o mesmo
// recurso do service_order_fiscal_section_test.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/widget/service_order_fiscal_section.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _orderId = 7374;
const _reason = 'Serviço não prestado no mês';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');
const _cancelledOrder = ServiceOrderFull(id: _orderId, customerId: 1, status: 'C');
const _authorizedVoice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);
const _authorizedTx = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');
const _local = ServiceOrderInvoiceCancelResult(orderId: _orderId, invoiceNumber: '704', event: 3);
// o 409 da nfse-api / do setes-api por contenção (`contentionToHttpError` — "Registro em uso por outra operação — tente novamente")
const _busy = Failure(message: 'Registro em uso por outra operação — tente novamente', statusCode: 409, code: 'RESOURCE_BUSY');

ServiceOrderCancelPlan _onlyAuthority() => const ServiceOrderCancelPlan(orderId: _orderId, fiscalRecord: true, blocks: [
      CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
    ]);

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

Future<List<String>> _pumpSection(WidgetTester tester, ServiceOrderDetailState state) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ServiceOrderFiscalSection(
          state: state,
          onTransmit: () => calls.add('transmit'),
          onFiscalRefresh: () => calls.add('refresh'),
          onFiscalXml: () => calls.add('xml'),
          onFiscalDanfse: () => calls.add('danfse'),
          onCancelInvoice: () => calls.add('cancel-flow'),
          onKeepInvoice: () => calls.add('keep'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;
  final pt = _load('pt');
  final so = (pt['forms'] as Map<String, dynamic>)['serviceOrder'] as Map<String, dynamic>;
  final decideRow = so['fiscalEffectDecideRow'] as String;
  final keep = so['fiscalKeep'] as String;
  final substitutedRow = so['fiscalSubstitutedRow'] as String;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(const ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0));
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => const Right(PagedResult.empty()));
    when(() => repo.getById(_orderId)).thenAnswer((_) async => const Right(_order));
    when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Right(_authorizedVoice));
    when(() => invoice.fiscalEffect(_orderId)).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
    when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => Right(_onlyAuthority()));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<ServiceOrderBloc> opened() async {
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
    bloc.add(const ServiceOrderViewRequested(_orderId));
    await shown;
    return bloc;
  }

  Future<List<ServiceOrderState>> runDetail(ServiceOrderBloc bloc, ServiceOrderEvent event) async {
    final states = <ServiceOrderState>[];
    final sub = bloc.stream.listen(states.add);
    final done = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && !s.saving);
    bloc.add(event);
    await done;
    await sub.cancel();
    await bloc.close();
    return states;
  }

  Future<FiscalTransmitBatchReport> runBatch(Map<int, Either<Failure, ServiceOrderTransmitResult>> by, List<int> ids) async {
    when(() => nfse.transmit(any())).thenAnswer((inv) async => by[inv.positionalArguments[0] as int]!);
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
    bloc.add(ServiceOrderFiscalTransmitBatchRequested(ids));
    final r = (await done as ServiceOrderFiscalBatchDone).report;
    await bloc.close();
    return r;
  }

  // ---------------------------------------------------------------------
  // 1. D-F163 — RESOURCE_BUSY: ato = desconhecido; o resto segue falha comum
  // ---------------------------------------------------------------------
  group('D-F163 — 409 RESOURCE_BUSY', () {
    test('[RESISTIU] cancelar NO FISCO com RESOURCE_BUSY → "resultado incerto — consulte" e o ERP NUNCA é chamado; reconferir idem', () async {
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(_busy));
      when(() => invoice.cancel(any(), any())).thenAnswer((_) async => const Right(_local));
      final c = await runDetail(await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(c.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown');
      verifyNever(() => invoice.cancel(any(), any()));
      when(() => nfse.reconfirm(_orderId)).thenAnswer((_) async => const Left(_busy));
      final r = await runDetail(await opened(), const ServiceOrderFiscalReconfirmRequested(_orderId));
      expect(r.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown');
    });

    test('[RESISTIU] RESOURCE_BUSY FORA do fisco segue o que é: plano relido (nada foi ao fisco) = falha comum; o ERP depois de o fisco cancelar = "falta aplicar na nota"; o "Aplicar" (sem fisco) = falha comum (o ERP desfez)', () async {
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Left(_busy));
      final plan = await runDetail(await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      verifyNever(() => nfse.cancel(any(), any()));
      expect([plan.whereType<ServiceOrderFiscalNotice>().length, plan.whereType<ServiceOrderActionFailure>().single.failure], [0, _busy]);

      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => Right(_onlyAuthority()));
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId)));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(_busy));
      final afterFisco = await runDetail(await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(afterFisco.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalLocalCancelPending');

      final apply = await runDetail(await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: false));
      expect([apply.whereType<ServiceOrderFiscalNotice>().length, apply.whereType<ServiceOrderActionFailure>().single.failure], [0, _busy]);
    });

    test('[RESISTIU] LEITURAS com RESOURCE_BUSY: abrir a OS → "indisponível" (nunca o aviso de incerto); Consultar → falha comum', () async {
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Left(_busy));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && s.fiscalFailure != null);
      bloc.add(const ServiceOrderViewRequested(_orderId));
      expect((await shown as ServiceOrderDetailState).fiscalFailure, _busy);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderFiscalNotice>(), isEmpty);
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Right(_authorizedVoice));
      when(() => nfse.refresh(_orderId)).thenAnswer((_) async => const Left(_busy));
      final r = await runDetail(await opened(), const ServiceOrderFiscalRefreshRequested(_orderId));
      expect([r.whereType<ServiceOrderFiscalNotice>().length, r.whereType<ServiceOrderActionFailure>().single.failure], [0, _busy]);
    });

    test('[FATO — decidido D-F163] lote: 3 RESOURCE_BUSY SEGUIDOS param o lote (as seguintes "não tentadas"); busy, ok, busy, busy segue', () async {
      final stop = await runBatch({1: const Left(_busy), 2: const Left(_busy), 3: const Left(_busy), 4: const Right(_authorizedTx)}, [1, 2, 3, 4]);
      expect([stop.stoppedBy, stop.transmitted, stop.rows.last.code], [_busy, 0, FiscalTransmitBatchRow.abortedCode]);
      final goOn = await runBatch({1: const Left(_busy), 2: const Right(_authorizedTx), 3: const Left(_busy), 4: const Left(_busy)}, [1, 2, 3, 4]);
      expect([goOn.stoppedBy, goOn.transmitted, goOn.refused, goOn.uncertain], [null, 1, 0, 3]);   // D-F168: desconhecido = incerta
    });

    test('[DECIDIDO D-F168 (= Q-F176 (a)) — era R6-ADV-05 LOW] no RELATÓRIO do lote o desfecho DESCONHECIDO (RESOURCE_BUSY depois do fisco — a razão da D-F163 —, e também 5xx/rede da D-F155) conta como "Recusada" e a linha leva a frase do servidor "tente novamente" — o oposto do "resultado incerto — consulte" que a D-F163 manda dizer: a NFS-e pode ter sido AUTORIZADA e o relatório diz "recusada". Correção sugerida: o relatório separa "incertas — consulte" (contador e linha próprios, com a frase de fiscalOutcomeUnknown) das recusas', () async {
      final r = await runBatch({1: const Left(_busy), 2: const Right(_authorizedTx)}, [1, 2]);
      expect(r.refusedRows.map((x) => x.orderId), isNot(contains(1)));
      expect([r.uncertain, r.uncertainRows.single.orderId, r.transmitted], [1, 1, 1]);
    });
  });

  // ---------------------------------------------------------------------
  // 2. D-F159 — a linha do ERP no `decide` com a voz fora
  // ---------------------------------------------------------------------
  group('D-F159 — voz fora + efeito decide', () {
    testWidgets('[RESISTIU] voz INDISPONÍVEL + decide: a linha do ERP aparece UMA vez, junto do "Manter a nota" (que chama o callback)', (tester) async {
      final calls = await _pumpSection(tester, const ServiceOrderDetailState(
        order: _order,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));
      expect(find.text(decideRow), findsOneWidget);
      await tester.tap(find.text(keep));
      expect(calls, ['keep']);
    });

    testWidgets('[RESISTIU] voz COM o bloco da substituição + decide: a frase é a da VOZ, a do ERP não se repete', (tester) async {
      await _pumpSection(tester, const ServiceOrderDetailState(
        order: _order,
        fiscal: ServiceOrderFiscalView(state: NfseState.cancelled, currentAttempt: 1, substitution: ServiceOrderFiscalSubstitution()),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));
      expect([find.text(decideRow).evaluate().length, find.text(substitutedRow).evaluate().length, find.text(keep).evaluate().length], [0, 1, 1]);
    });

    testWidgets('[RESISTIU] nota CANCELADA ou decisão já registrada (efeito none + dispensa): nem a linha nem o "Manter a nota"', (tester) async {
      await _pumpSection(tester, const ServiceOrderDetailState(
        order: _cancelledOrder,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));
      expect([find.text(decideRow).evaluate().length, find.text(keep).evaluate().length], [0, 0]);
      await _pumpSection(tester, const ServiceOrderDetailState(
        order: _order,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503),
        effect: ServiceOrderFiscalEffect(cancelWaiver: ServiceOrderFiscalCancelWaiver(accessKey: 'K', reason: 'mantida', createdAt: '2026-10-12 10:00:00')),
      ));
      expect([find.text(decideRow).evaluate().length, find.text(keep).evaluate().length], [0, 0]);
    });

    testWidgets('[FATO — as duas fontes em instantes diferentes] a voz RESPONDEU (sem o bloco da substituição — lida antes da voz C pousar) e o ERP diz decide: a linha do ERP afirma "os detalhes do fisco estão indisponíveis agora" com a voz na tela', (tester) async {
      await _pumpSection(tester, const ServiceOrderDetailState(
        order: _order,
        fiscal: _authorizedVoice,
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));
      expect(find.text(decideRow), findsOneWidget);
    });

    testWidgets('[FATO] sem o privilégio CANCELAR a linha manda "decida" e não há botão (a decisão é de quem pode)', (tester) async {
      CurrentInterface.value = _iface(['TRANSMITIR']);
      await _pumpSection(tester, const ServiceOrderDetailState(
        order: _order,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));
      expect([find.text(decideRow).evaluate().length, find.text(keep).evaluate().length], [1, 0]);
    });

    test('[RESISTIU] a chave nova existe em pt e en (nenhuma chave crua na tela)', () {
      final en = (_load('en')['forms'] as Map<String, dynamic>)['serviceOrder'] as Map<String, dynamic>;
      expect([(so['fiscalEffectDecideRow'] as String).isNotEmpty, (en['fiscalEffectDecideRow'] as String).isNotEmpty], [true, true]);
    });
  });

  // ---------------------------------------------------------------------
  // 3. D-F160 — só o onDispose do módulo para os lotes
  // ---------------------------------------------------------------------
  group('D-F160 — a página recriada (troca de layout) não para o lote', () {
    test('[RESISTIU] o dispose da PÁGINA não chama stopBatches; o onDispose do MÓDULO chama stopBatches e close', () {
      final page = File('lib/app/modules/service_orders/presentation/page/service_order_page.dart').readAsStringSync();
      final i = page.indexOf('void dispose()');
      final body = page.substring(i, page.indexOf('super.dispose();', i));
      expect(RegExp(r'^\s*[^/\s].*stopBatches', multiLine: true).hasMatch(body), isFalse);
      final module = File('lib/app/modules/service_orders/service_orders_module.dart').readAsStringSync();
      expect(RegExp(r'onDispose:\s*\(bloc\)\s*\{\s*bloc\.stopBatches\(\);\s*bloc\.close\(\);').hasMatch(module), isTrue);
    });

    test('[RESISTIU] a página recriada no meio do lote (o initState dela pede a lista): o lote SEGUE até o fim e o relatório sai', () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((inv) async {
        if (inv.positionalArguments[0] == 1) await gate.future;
        return const Right(_authorizedTx);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2, 3]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                  // o initState da página nova
      await pumpEventQueue();
      gate.complete();
      final report = (await done as ServiceOrderFiscalBatchDone).report;
      await bloc.close();
      expect([report.transmitted, report.stoppedBy], [3, null]);
    });

    test('[DECIDIDO D-F169 (= Q-F177 (a)) — era R6-ADV-06 LOW] com o lote AINDA rodando, a página recriada (cruzar 1100 px — o caso da D-F160) pede a lista e o bloc a devolve com `loading: false`: a trava dos botões do H1 (gate da Rodada 5 — "o lote em andamento mantém a lista em loading — sem duplo disparo") REABRE, a tela parece ociosa com o lote no ar e um novo "Transmitir pendentes" é IGNORADO calado (`_fiscalBatchRunning`); se o operador, achando que nada roda, sair da tela, o lote para (D-F160); se abrir uma OS, o fim do lote o tira do detalhe. Correção sugerida: enquanto um lote roda, a lista sai sempre em loading (ou um estado "lote em andamento" que a página recriada respeite)', () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((inv) async {
        if (inv.positionalArguments[0] == 1) await gate.future;
        return const Right(_authorizedTx);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue();
      final whileRunning = states.whereType<ServiceOrderListState>().last;
      gate.complete();
      await bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      await sub.cancel();
      await bloc.close();
      expect(whileRunning.loading, isTrue, reason: 'o lote ainda rodava e a lista saiu "ociosa"');
    });

    test('[DECIDIDO D-F174 (= Q-F182 (b)) — era o FATO base do R6-ADV-06] o fim do lote mostra o relatório e NÃO tira o operador do detalhe que ele abriu no meio', () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((inv) async {
        if (inv.positionalArguments[0] == 1) await gate.future;
        return const Right(_authorizedTx);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue();
      final detail = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
      bloc.add(const ServiceOrderViewRequested(_orderId));                                   // o operador abre uma OS
      await detail;
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      gate.complete();
      await done;
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final shown = states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).toList();
      expect(shown.last, isA<ServiceOrderDetailState>(), reason: 'o operador segue na OS que abriu');
      expect(states.whereType<ServiceOrderFiscalBatchDone>(), hasLength(1), reason: 'o relatório sai');
    });
  });
}
