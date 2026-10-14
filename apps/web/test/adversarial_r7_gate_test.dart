// GATE ADVERSARIAL do DELTA da Rodada 7 da F2a/F2b (setes-app) — alvo: commit
// e89231e (delta sobre 3b5b2b6): D-F168 (relatório do lote fiscal com
// "incertas — consulte" separadas das recusadas), D-F169 (lista em loading
// enquanto um lote roda; cada lote baixa a marca antes da recarga final) e a
// correção R6-SOC-01 (frase "decisão já registrada" só com a dispensa gravada
// ou a nota cancelada; senão a neutra).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R7-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r7_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:easy_localization/easy_localization.dart';
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

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _tx = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');
const _busy = Failure(message: 'Registro em uso por outra operação — tente novamente', statusCode: 409, code: 'RESOURCE_BUSY');
const _internal = Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'ab12cd');
const _gateway = Failure(message: 'Bad gateway', statusCode: 503);
const _rejected = Failure(message: 'Rejeitada pelo fisco', statusCode: 422, code: 'FISCAL_DPS_REJECTED');
const _rule = Failure(message: 'Nota sem ramo de serviço', statusCode: 409, code: 'INVOICE_NOT_SERVICE');
const _order = ServiceOrderFull(id: 7374, customerId: 1, status: 'F');
const _cancelledOrder = ServiceOrderFull(id: 7374, customerId: 1, status: 'C');
const _substituted = ServiceOrderFiscalView(
    state: NfseState.cancelled, currentAttempt: 1, substitution: ServiceOrderFiscalSubstitution(substituteAccessKey: 'S'));

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

BatchInvoiceReport _invoiced(List<int> ids) => BatchInvoiceReport.fromEntries([
      for (final id in ids) BatchInvoiceEntry(orderId: id, ok: true, invoiceNumber: '$id', chargedParcels: 1, chargeableParcels: 1),
    ]);

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;
  final pt = _load('pt');
  final en = _load('en');
  final so = (pt['forms'] as Map<String, dynamic>)['serviceOrder'] as Map<String, dynamic>;
  final soEn = (en['forms'] as Map<String, dynamic>)['serviceOrder'] as Map<String, dynamic>;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => const Right(PagedResult.empty()));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<FiscalTransmitBatchReport> runFiscal(Map<int, Either<Failure, ServiceOrderTransmitResult>> by, List<int> ids) async {
    when(() => nfse.transmit(any())).thenAnswer((inv) async => by[inv.positionalArguments[0] as int]!);
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
    bloc.add(ServiceOrderFiscalTransmitBatchRequested(ids));
    final r = (await done as ServiceOrderFiscalBatchDone).report;
    await bloc.close();
    return r;
  }

  // ---------------------------------------------------------------------
  // 1. D-F168 — o relatório do lote fiscal
  // ---------------------------------------------------------------------
  group('D-F168 — incertas × recusadas × não tentadas', () {
    test('[RESISTIU — D-F171] 3 desfechos DESCONHECIDOS seguidos (rede, 500 INTERNAL, 503 sem código) param o lote: 3 incertas, as 2 não tentadas com contador PRÓPRIO (D-F171), nunca como incertas nem recusadas; o lote parou pela 3ª', () async {
      final r = await runFiscal({
        1: const Left(NetworkFailure()), 2: const Left(_internal), 3: const Left(_gateway), 4: const Right(_tx), 5: const Right(_tx),
      }, [1, 2, 3, 4, 5]);
      expect([r.transmitted, r.uncertain, r.refused, r.notTried, r.requested], [0, 3, 0, 2, 5]);
      expect(r.uncertainRows.map((x) => x.orderId), [1, 2, 3]);
      expect(r.notTriedRows.map((x) => [x.orderId, x.code, x.unknown]), [
        [4, FiscalTransmitBatchRow.abortedCode, false],
        [5, FiscalTransmitBatchRow.abortedCode, false],
      ]);
      expect(r.stoppedBy, _gateway);
    });

    test('[RESISTIU — D-F171] incerta seguida de erro SISTÊMICO (401 "sessão não aceita"): a incerta segue incerta, a sistêmica é RECUSADA (não incerta) e para o lote; a seguinte "não tentada" (contador próprio)', () async {
      const session = UnauthorizedFailure(code: ClientFailureCodes.sessionNotAccepted);
      final r = await runFiscal({1: const Left(_busy), 2: const Left(session), 3: const Right(_tx)}, [1, 2, 3]);
      expect([r.uncertain, r.refused, r.notTried, r.transmitted], [1, 1, 1, 0]);
      expect(r.uncertainRows.single.orderId, 1);
      expect([r.refusedRows.map((x) => x.orderId).toList(), r.notTriedRows.map((x) => x.orderId).toList()], [[2], [3]]);
      expect(r.stoppedBy, session);
    });

    test('[RESISTIU] mistura sem parar: 422 do fisco e 409 de regra = RECUSADAS; resposta ilegível (2xx torto) e 504 sem código = INCERTAS; a soma das três contas é SEMPRE o pedido (nenhuma linha contada duas vezes)', () async {
      final r = await runFiscal({
        1: const Left(_rejected), 2: const Left(_rule), 3: Left(invalidResponseFailure('x', service: 'setes-api')), 4: const Right(_tx),
        5: const Left(Failure(message: 'gw', statusCode: 504)),
      }, [1, 2, 3, 4, 5]);
      expect([r.transmitted, r.refused, r.uncertain, r.stoppedBy], [1, 2, 2, null]);
      expect(r.refusedRows.map((x) => x.orderId), [1, 2]);
      expect(r.uncertainRows.map((x) => x.orderId), [3, 5]);
      expect(r.transmitted + r.refused + r.uncertain, r.requested);
    });

    test('[RESISTIU — D-F171/R7-SOC-02] as chaves novas existem em pt e en com o número CERTO de lacunas (1 em cada parte do resumo, 2 na linha incerta — ordem + código/ref, 1 na não tentada, 0 na parada por incertas) — nenhuma chave crua nem argumento sobrando na tela', () {
      int holes(String s) => '{}'.allMatches(s).length;
      for (final m in [so, soEn]) {
        expect([
          holes(m['fiscalBatchSummaryUncertainPart'] as String), holes(m['fiscalBatchSummaryNotTriedPart'] as String),
          holes(m['fiscalBatchUncertainRow'] as String), holes(m['fiscalBatchNotTriedRow'] as String),
          holes(m['fiscalBatchStoppedUncertain'] as String),
        ], [1, 1, 1, 1, 0]);   // R8-SOC-02: a incerta tem 1 lacuna (o complemento sai do código, só com conteúdo)
        expect((m['fiscalSubstitutedNeutralRow'] as String).isNotEmpty, isTrue);
      }
    });

    test('[CORRIGIDO R7-ADV-06 LOW — R7-SOC-02 (i)] lote PARADO por 3 incertas seguidas (D-F163: RESOURCE_BUSY depois do fisco): a linha "O lote parou: …" leva a mensagem CRUA da 3ª incerta — "Registro em uso por outra operação — tente novamente" (ou "Fisco indisponível … — tente depois") — logo acima das linhas "resultado incerto — consulte a situação no fisco ANTES de transmitir de novo". O resumo manda repetir e não repetir ao mesmo tempo (o resíduo do R6-ADV-05 que a D-F168 corrigiu só nas LINHAS). Correção sugerida: parada por incertas seguidas = frase PRÓPRIA ("o lote parou: N resultados incertos seguidos — consulte antes de repetir"); a mensagem do servidor só para a parada SISTÊMICA', () async {
      final r = await runFiscal({1: const Left(_busy), 2: const Left(_busy), 3: const Left(_busy), 4: const Right(_tx)}, [1, 2, 3, 4]);
      // a MESMA composição da página (`_showFiscalBatchSummary`) — conferida contra o fonte abaixo
      final page = File('lib/app/modules/service_orders/presentation/page/service_order_page.dart').readAsStringSync();
      // parada por desfechos DESCONHECIDOS = frase própria; a mensagem do servidor só na parada SISTÊMICA
      expect(page, matches(RegExp(r"isUnknownAuthorityOutcome\(stopped\)\r?\n\s+\? 'forms\.serviceOrder\.fiscalBatchStoppedUncertain'\.tr\(\)")));
      expect(isUnknownAuthorityOutcome(r.stoppedBy!), isTrue);
      final stopLine = 'forms.serviceOrder.fiscalBatchStoppedUncertain'.tr();
      expect(stopLine, isNot(contains('tente novamente')));
      expect(stopLine, contains('consulte'));
    });

    test('[FATO — base do R7-ADV-06] hoje: 3 RESOURCE_BUSY seguidos → stoppedBy = o 3º (mensagem "… — tente novamente"); a frase da página é "O lote parou: Registro em uso por outra operação — tente novamente"', () async {
      final r = await runFiscal({1: const Left(_busy), 2: const Left(_busy), 3: const Left(_busy), 4: const Right(_tx)}, [1, 2, 3, 4]);
      expect([r.uncertain, r.refused, r.notTried, r.stoppedBy], [3, 0, 1, _busy]);   // D-F171: a 4ª é NÃO TENTADA, não "recusada"
      expect('forms.serviceOrder.fiscalBatchStopped'.tr(args: [r.stoppedBy!.message.tr()]),
          'O lote parou: Registro em uso por outra operação — tente novamente');
    });

    test('[CORRIGIDO R7-ADV-05 LOW — R7-SOC-02 (iii)] a linha "incerta" do relatório perde o código E o `ref` de suporte da falha: o 500 `INTERNAL` da nfse-api (D-F155 — "ela pode ter falhado DEPOIS de falar com o fisco") traz `ref` — a ÚNICA ponte para o log do servidor que diz se a NFS-e foi ao fisco —, mas a linha guarda só `orderId/ok/code/message/unknown` e a frase da tela ("Ordem N: resultado incerto — consulte…") não leva nem o código (as recusadas levam código + mensagem — F2B-ADV-14). No detalhe a seção mostra o ref (F2B-SOC-10); no lote ele some. Correção sugerida: a linha do lote guarda o `supportRef` e a frase da incerta o anexa ("— código de suporte X") quando houver', () async {
      final r = await runFiscal({1: const Left(_internal)}, [1]);
      final row = r.uncertainRows.single;
      expect(row.supportRef, 'ab12cd');
    });
  });

  // ---------------------------------------------------------------------
  // 2. D-F169 — a lista em loading com um lote no ar
  // ---------------------------------------------------------------------
  group('D-F169 — a lista presa ou livre na hora certa', () {
    test('[RESISTIU] os DOIS lotes ao mesmo tempo (fiscal + faturamento): enquanto QUALQUER um roda, toda lista sai em loading — inclusive a recarga final do 1º que termina; só a recarga final do ÚLTIMO sai livre', () async {
      final gateF = Completer<void>();
      final gateI = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gateF.future;
        return const Right(_tx);
      });
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        await gateI.future;
        return Right(_invoiced(inv.positionalArguments[0] as List<int>));
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [10], input: _input));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                 // a página recriada
      await pumpEventQueue();
      final invoiceDone = bloc.stream.firstWhere((s) => s is ServiceOrderBatchInvoiceDone);
      gateI.complete();
      await invoiceDone;
      await pumpEventQueue();
      final whileFiscal = states.whereType<ServiceOrderListState>().toList();
      final free = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      gateF.complete();
      await free;
      await sub.cancel();
      await bloc.close();
      expect(whileFiscal.length, greaterThanOrEqualTo(4));
      expect(whileFiscal.every((s) => s.loading), isTrue, reason: 'o lote fiscal ainda rodava');
      expect(states.whereType<ServiceOrderFiscalBatchDone>().length, 1);
      expect((states.last as ServiceOrderListState).loading, isFalse);
    });

    test('[RESISTIU] faturamento cujo 1º bloco FALHA inteiro (403): a falha sobe como sempre e a recarga final sai LIVRE; a lista pedida no meio saiu em loading', () async {
      final gate = Completer<void>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async {
        await gate.future;
        return const Left(Failure(message: 'Sem privilégio', statusCode: 403));
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue();
      final during = states.whereType<ServiceOrderListState>().last;
      final free = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      gate.complete();
      await free;
      await sub.cancel();
      await bloc.close();
      expect(during.loading, isTrue);
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.statusCode, 403);
      expect((states.last as ServiceOrderListState).loading, isFalse);
    });

    test('[RESISTIU] a LISTA falha no meio do lote: sai em loading (sem itens) — a recarga final do lote, que dá certo, sai livre', () async {
      var over = false;
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => over ? const Right(PagedResult.empty()) : const Left(Failure(message: 'fora', statusCode: 503)));
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gate.future;
        over = true;
        return const Right(_tx);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
      await pumpEventQueue();
      final during = states.whereType<ServiceOrderListState>().last;
      final free = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
      gate.complete();
      await free;
      await sub.cancel();
      await bloc.close();
      expect([during.loading, during.items.isEmpty], [true, true]);
      expect((states.last as ServiceOrderListState).loading, isFalse);
    });

    test('[FATO — exige o `close` junto] `stopBatches()` SEM fechar o bloc: o lote para sem a recarga final e a lista FICA em loading. Inalcançável hoje — o único chamador é o `onDispose` do MÓDULO, que chama `stopBatches()` e `close()` juntos (cerca do gate R6); quem chamar `stopBatches` sozinho no futuro prende a tela', () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gate.future;
        return const Right(_tx);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      await pumpEventQueue();
      bloc.stopBatches();
      gate.complete();
      await pumpEventQueue(times: 50);
      await sub.cancel();
      expect(states.whereType<ServiceOrderFiscalBatchDone>(), isEmpty);
      expect((states.whereType<ServiceOrderListState>().last).loading, isTrue);
      await bloc.close();
    });

    test('[CORRIGIDO — R7-SOC-03 (era o FATO da corrida anterior à D-F169)] a lista pedida NO MEIO do lote cuja resposta chega DEPOIS da recarga final é DESCARTADA (recarga superada): a lista final fica a fresca, com os selos de depois do lote', () async {
      final slow = Completer<void>();
      var call = 0;
      const stale = ServiceOrderListItem(id: 1, customerId: 1, status: 'F');
      const fresh = ServiceOrderListItem(id: 1, customerId: 1, status: 'F', fiscalState: NfseState.authorized, nfseNumber: '705');
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async {
        call += 1;
        if (call == 1) {
          await slow.future;
          return const Right(PagedResult(items: [stale], page: 1, pageSize: 10, total: 1));
        }
        return const Right(PagedResult(items: [fresh], page: 1, pageSize: 10, total: 1));
      });
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gate.future;
        return const Right(_tx);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));                 // fica pendurada (call 1)
      await pumpEventQueue();
      final finalList = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading && s.items.isNotEmpty);
      gate.complete();
      await finalList;                                                                    // a recarga final (call 2): fresca
      slow.complete();                                                                    // a velha chega depois
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = states.whereType<ServiceOrderListState>().last;
      expect([last.loading, last.items.single.fiscalState], [false, NfseState.authorized]);
    });
  });

  // ---------------------------------------------------------------------
  // 3. R6-SOC-01 — a frase da substituição
  // ---------------------------------------------------------------------
  group('R6-SOC-01 — "decisão já registrada" só quando o ERP diz', () {
    final undecided = so['fiscalSubstitutedRow'] as String;
    final decided = so['fiscalSubstitutedDecidedRow'] as String;
    final neutral = so['fiscalSubstitutedNeutralRow'] as String;

    Future<String> phrase(WidgetTester tester, ServiceOrderDetailState state) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceOrderFiscalSection(
              state: state,
              onTransmit: () {}, onFiscalRefresh: () {}, onFiscalXml: () {}, onFiscalDanfse: () {},
              onCancelInvoice: () {}, onKeepInvoice: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final p in [undecided, decided, neutral]) {
        if (find.text(p).evaluate().isNotEmpty) return p;
      }
      return '(nenhuma)';
    }

    testWidgets('[RESISTIU] a matriz: decide → "até você decidir"; dispensa gravada → "já registrada"; nota cancelada (com ou sem o ERP) → "já registrada"; ERP INDISPONÍVEL, `cancel` (homologação), `apply` e `none` sem dispensa → NEUTRA', (tester) async {
      const waiver = ServiceOrderFiscalCancelWaiver(accessKey: 'K', reason: 'mantida', createdAt: '2026-10-12 10:00:00');
      final cases = <String, (ServiceOrderDetailState, String)>{
        'decide': (const ServiceOrderDetailState(order: _order, fiscal: _substituted, effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide)), undecided),
        'dispensa': (const ServiceOrderDetailState(order: _order, fiscal: _substituted, effect: ServiceOrderFiscalEffect(cancelWaiver: waiver)), decided),
        'cancelada+ERP fora': (const ServiceOrderDetailState(order: _cancelledOrder, fiscal: _substituted, effectFailure: Failure(message: 'fora', statusCode: 503)), decided),
        'cancelada+decide': (const ServiceOrderDetailState(order: _cancelledOrder, fiscal: _substituted, effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide)), decided),
        'ERP fora': (const ServiceOrderDetailState(order: _order, fiscal: _substituted, effectFailure: Failure(message: 'fora', statusCode: 503)), neutral),
        'cancel (H)': (const ServiceOrderDetailState(order: _order, fiscal: _substituted, effect: ServiceOrderFiscalEffect(effect: FiscalEffect.cancel)), neutral),
        'apply': (const ServiceOrderDetailState(order: _order, fiscal: _substituted, effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply)), neutral),
        'none': (const ServiceOrderDetailState(order: _order, fiscal: _substituted, effect: ServiceOrderFiscalEffect()), neutral),
      };
      final got = <String, String>{};
      for (final e in cases.entries) {
        got[e.key] = await phrase(tester, e.value.$1);
      }
      expect(got, {for (final e in cases.entries) e.key: e.value.$2});
    });
  });
}
