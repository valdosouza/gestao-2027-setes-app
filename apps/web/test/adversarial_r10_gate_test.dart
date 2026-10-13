// GATE ADVERSARIAL do DELTA COMBINADO (correções dos gates da Rodada 9 +
// Rodada 10) da F2a/F2b (setes-app) — alvo: `3766f39..3174d54` (branch f2b):
// UM contador da tela (`_screenGeneration` — vale o último pedido),
// `_showListLoading` (limpa o `_detail`; `supersede: false` nas operações
// longas), `_pendingDetailScreen`/`_onDetail` (aberto OU a caminho),
// `_fetchFiscal` (a voz como valor, gravada com o detalhe), a guarda D-F174 nos
// fins de lote e (D-F177) na rotina mensal e nas pendentes, o botão da rotina
// mensal travado pelo loading, D-F176 (linha incerta: "HTTP 503" sem código;
// "sem conexão" com a rede caída) e D-F178 (o detalhe preservado não é relido).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R10-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r10_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre) — cada ACHADO
//     tem o seu FATO, que é a PROVA executável de hoje.
// Nada aqui fala com servidor: repositórios mocktail (molde do gate R9).
//
// CORREÇÕES na mesma sessão (= R10-SOC-01/R10-SOC-03 do gate socrático): R10-ADV-02 (a marca "a caminho" só morre onde o `_detail`
// nasce, ou na falha) e R10-ADV-03 (o ato no detalhe confere a tela que capturou ao começar — `_stillOnDetail`) — as provas FATO
// viraram `[CORRIGIDO …]` (a mesma sequência, o comportamento novo) e os ACHADOS rodam sempre. R10-ADV-01 aguarda o Valdo (Q-F187).

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
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

/// A OS NOVA que o FAB abre (aberta — sem seção fiscal) e uma OS FATURADA (com a seção "No fisco": voz + efeito).
const _newId = 77;
const _newOrder = ServiceOrderFull(id: _newId, customerId: 5);
const _billedId = 7374;
const _billed = ServiceOrderFull(id: _billedId, customerId: 1, status: 'F');
const _voice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);

const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';
const _blocSrc = 'lib/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

BatchInvoiceReport _okReport(List<int> ids) =>
    BatchInvoiceReport.fromEntries([for (final id in ids) BatchInvoiceEntry(orderId: id, ok: true)]);

PagedResult<ServiceOrderListItem> _page(List<int> ids, {int page = 1, int? total}) => PagedResult(
    items: [for (final id in ids) ServiceOrderListItem(id: id, customerId: 1)], page: page, pageSize: 10, total: total ?? ids.length);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState _shown(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).last;

const _skipAchado = 'ACHADO do gate R10 — descreve o comportamento CERTO; hoje falha (ver o FATO irmão). '
    'Rodar: flutter test --run-skipped test/adversarial_r10_gate_test.dart';

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;
  late int listCalls;
  final pt = _load('pt');

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  /// A lista padrão: responde na hora (cada chamada conta).
  void listAnswersNow() {
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async {
      listCalls++;
      return Right(_page([1, 2]));
    });
  }

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    listCalls = 0;
    listAnswersNow();
    when(() => repo.open(5)).thenAnswer((_) async => const Right(_newId));
    when(() => repo.getById(_newId)).thenAnswer((_) async => const Right(_newOrder));
    when(() => repo.getById(_billedId)).thenAnswer((_) async => const Right(_billed));
    when(() => invoice.fiscalEffect(_billedId)).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>)> start() async {
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final states = <ServiceOrderState>[];
    final sub = bloc.stream.listen(states.add);
    return (bloc, states, sub);
  }

  Future<void> openByFab(ServiceOrderBloc bloc, List<ServiceOrderState> states) async {
    bloc.add(const ServiceOrderOpenRequested(5));
    await pumpEventQueue();
    expect(_shown(states), isA<ServiceOrderDetailState>(), reason: 'o FAB abriu a OS nova');
    expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
  }

  // ---------------------------------------------------------------------
  // 1. D-F177 — "o botão da rotina mensal fica TRAVADO pelo loading, como os
  //    botões de lote (H1)"
  // ---------------------------------------------------------------------
  group('D-F177 — a trava da rotina mensal', () {
    test('[FATO — prova do R10-ADV-01] a trava da rotina mensal é SÓ o `state.loading` da página: com a rotina no ar (minutos com N contratos), qualquer recarga da lista que o operador pede no spinner (trocar de ABA, filtro, pesquisa avançada — todos ativos no loading; a página recriada no resize) sai com `loading: false` — a rotina não entra no `_batchInFlight` da D-F169 — e REABRE os botões: a 2ª rotina mensal é disparada (o bloc não tem trava de reentrância para ela) e o lote de faturamento também, em paralelo com a rotina. O mesmo no passo 1 do lote fiscal ("Transmitir pendentes"): duas fotografias em voo, dois diálogos de confirmação', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      var runs = 0;
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) {
        runs++;
        return run.future;
      });
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async => Right(_okReport([1])));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      expect((_shown(states) as ServiceOrderListState).loading, isTrue, reason: 'a trava H1 vale no começo');
      bloc.add(const ServiceOrderListRequested(status: 'F'));                       // troca de aba no spinner
      await pumpEventQueue(times: 20);
      final mid = _shown(states) as ServiceOrderListState;
      expect([mid.status, mid.loading, runs], ['F', false, 1], reason: 'a lista da aba sai LIVRE com a rotina no ar');
      bloc.add(const ServiceOrderListRequested(status: 'A'));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));         // o botão está habilitado
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue(times: 20);
      expect(runs, 2, reason: 'a 2ª rotina mensal foi ao servidor com a 1ª no ar');
      verify(() => repo.batchInvoice(any(), any())).called(1);                         // e o lote, em paralelo com a rotina
      run.complete(const Right(MonthlyRunReport(processed: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(File(_pageSrc).readAsStringSync(), contains('onPressed: state.loading ? null : _openMonthlyRun,'));
      expect(File(_blocSrc).readAsStringSync(),
          matches(RegExp(r'_onMonthlyRunRequested\([^)]*\) async \{\s*_showListLoading\(emit, supersede: false\);')),
          reason: 'nenhuma trava de reentrância antes de ir ao servidor (o lote tem `_batchRunning`)');
    });

    test('[FATO — prova do R10-ADV-01, passo 1 do lote fiscal] "Transmitir pendentes" com a fotografia no ar: trocar de aba (A e de volta a F) devolve a lista LIVRE e o botão reabre; o 2º clique manda a 2ª fotografia (a guarda é só `_fiscalBatchRunning`) — duas `FiscalPendingLoaded` = dois diálogos "N notas sem NFS-e — transmitir agora?"', () async {
      final pending = Completer<Either<Failure, PagedResult<ServiceOrderFiscalPending>>>();
      var asks = 0;
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) {
        asks++;
        return pending.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A'));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue();
      pending.complete(const Right(PagedResult(items: [ServiceOrderFiscalPending(invoiceId: 9)], page: 1, pageSize: 100, total: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([asks, states.whereType<ServiceOrderFiscalPendingLoaded>().length], [2, 2]);
    });

    test('[ACHADO R10-ADV-01 LOW] com a rotina mensal no ar a trava NÃO reabre: a lista pedida no meio (aba, filtro, página recriada) sai em loading, como no lote (D-F169), e uma 2ª rotina (ou um lote) não vai ao servidor — "travado pelo loading, como os botões de lote (H1)" (D-F177) só vale se o loading durar o que a rotina dura. Correção sugerida: a rotina mensal (e o passo 1 do lote fiscal) entram no `_batchInFlight` + trava de reentrância no handler, como o `_batchRunning`', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      var runs = 0;
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) {
        runs++;
        return run.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      final mid = _shown(states) as ServiceOrderListState;
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue(times: 20);
      run.complete(const Right(MonthlyRunReport(processed: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([mid.loading, runs], [true, 1]);
    }, skip: _skipAchado);
  });

  // ---------------------------------------------------------------------
  // 2. D-F174/D-F177 — "aberto OU a caminho": a janela da voz do fisco
  // ---------------------------------------------------------------------
  group('D-F177 — o detalhe a caminho na janela da voz do fisco', () {
    test('[CORRIGIDO R10-ADV-02 — era o FATO] `_reloadDetail` baixava a marca "a caminho" (`_pendingDetailScreen = null`) logo depois do GET da OS e SÓ grava o `_detail` depois da voz do fisco (`_fetchFiscal` — nfse-api + efeito do ERP, em paralelo): na janela entre os dois, `_onDetail` é FALSO. Com a rotina mensal no ar (a lista livre — R10-ADV-01), o operador abre uma OS FATURADA da aba Faturadas e a nfse-api demora; a rotina termina NESSA janela → o fim recarrega a lista (geração nova) → a voz chega e o detalhe é DESCARTADO: o operador volta à lista sem ter pedido — exatamente o que a D-F177 promete evitar ("com a OS aberta (ou a caminho) … a lista não é recarregada"). O mesmo no passo 1 do lote fiscal', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) => run.future);
      final voice = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => nfse.getView(_billedId)).thenAnswer((_) => voice.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(filter: '73'));                      // o filtro no spinner → lista LIVRE
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
      bloc.add(const ServiceOrderViewRequested(_billedId));                          // a OS faturada: GET ok, a voz demora
      await pumpEventQueue(times: 20);
      verify(() => repo.getById(_billedId)).called(1);
      final before = listCalls;
      run.complete(const Right(MonthlyRunReport(processed: 1)));                     // a rotina termina na janela da voz
      await pumpEventQueue(times: 20);
      voice.complete(const Right(_voice));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states);
      expect([listCalls, last is ServiceOrderDetailState && last.order.id == _billedId], [before, true],
          reason: 'o fim da rotina NÃO recarregou e a OS faturada pedida chegou à tela');
      // a marca morre DEPOIS da voz do fisco (junto com o `_detail`), nunca entre o GET e a voz
      expect(File(_blocSrc).readAsStringSync(),
          matches(RegExp(r'final fiscal = await _fetchFiscal\(full\);[\s\S]*?if \(_pendingDetailScreen == screen\) _pendingDetailScreen = null;[\s\S]*?_detail = full;')));
    });

    test('[CORRIGIDO R10-ADV-02 LOW] a OS pedida (ver OS) segue "a caminho" até o `_detail` nascer: o fim da rotina mensal na janela da voz do fisco mostra o relatório e NÃO recarrega — a tela termina na OS faturada que o operador abriu, com a voz dela. Correção sugerida: baixar a marca `_pendingDetailScreen` só onde o `_detail` nasce (ou na falha), não logo depois do GET', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) => run.future);
      final voice = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => nfse.getView(_billedId)).thenAnswer((_) => voice.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(filter: '73'));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue(times: 20);
      final before = listCalls;
      run.complete(const Right(MonthlyRunReport(processed: 1)));
      await pumpEventQueue(times: 20);
      voice.complete(const Right(_voice));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states);
      expect([listCalls, last is ServiceOrderDetailState && last.order.id == _billedId && last.fiscal == _voice], [before, true]);
    });
  });

  // ---------------------------------------------------------------------
  // 3. UM contador da tela × o ato NO detalhe: a geração é a de QUANDO o ato
  //    termina, não a de quando começou
  // ---------------------------------------------------------------------
  group('o ato no detalhe × a lista pedida no meio dele', () {
    test('[CORRIGIDO R10-ADV-03 — era o FATO] a recarga do detalhe de um ATO (item, transmitir, consultar, cancelar…) toma a geração de QUANDO o ato termina (`generation ?? _screenGeneration`), e o `_reloadList` zera o `_detail` no COMEÇO (não onde a lista é emitida): com um lote no ar e a OS do FAB aberta, o operador salva um item e a página é RECRIADA no meio (resize — D-F160; o `initState` pede a lista); o POST do item termina, o detalhe relido usa a geração DA LISTA, emite e grava o `_detail`; a lista (mais lenta) chega DEPOIS na mesma geração e também emite — a tela é a lista (em loading — o lote segue, D-F169) com o `_detail` VELHO. No fim do lote `_onDetail` é verdadeiro → só o relatório, nenhuma recarga: a tela fica PRESA no spinner (a classe do R9-SOC-02). Antes da correção do R9 o detalhe que emitia invalidava a lista (`_listGeneration++`) e a tela ficava coerente no detalhe', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      final item = Completer<Either<Failure, int>>();
      when(() => repo.itemPost(_newId, any())).thenAnswer((_) => item.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      bloc.add(const ServiceOrderItemSaveRequested(orderId: _newId, input: _item));
      await pumpEventQueue();
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      final slowList = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        listCalls++;
        return slowList.future;
      });
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));            // o initState da página recriada
      await pumpEventQueue();
      item.complete(const Right(1));                                                   // o item salvou: a tela já não é o detalhe → não relê
      await pumpEventQueue(times: 20);
      expect(_shown(states), isA<ServiceOrderListState>(), reason: 'o detalhe não volta por cima da lista pedida depois do ato');
      slowList.complete(Right(_page([1, 2])));                                         // a lista chega DEPOIS
      await pumpEventQueue(times: 20);
      expect([_shown(states) is ServiceOrderListState, (_shown(states) as ServiceOrderListState).loading], [true, true]);
      listAnswersNow();
      final before = listCalls;
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderBatchInvoiceDone>(), hasLength(1));
      verify(() => repo.getById(_newId)).called(1);                                     // só a abertura pelo FAB — o ato não releu
      final last = _shown(states) as ServiceOrderListState;
      expect([last.loading, listCalls], [false, before + 1], reason: 'o fim do lote recarrega a lista LIVRE — nada preso');
    });

    test('[CORRIGIDO R10-ADV-03, ramo da FALHA — era o FATO] a FALHA de um ato re-emitia o detalhe CAPTURADO no começo do ato (`if (detail != null) emit(_detailState(detail))` — item, faturar, cancelar OS, Consultar/XML/DANFSe/plano pelo `_fiscalAction`, Reconferir) sem conferir o contador da tela: na OS FATURADA (autorizada) o operador clica "Consultar"; a página é recriada no meio (resize) e a lista chega; a consulta falha (409 RESOURCE_BUSY) → o detalhe VOLTA por cima da lista com o `_detail`, a voz e o efeito NULOS (o `_reloadList` os zerou): a seção "No fisco" lê `view == null` como "NFS-e não transmitida" (a nota está AUTORIZADA) e sem nenhum botão; e o próximo ato não marca `saving` (o `_detail` é nulo) — dois cliques em "Consultar" mandam duas consultas', () async {
      when(() => nfse.getView(_billedId)).thenAnswer((_) async => const Right(_voice));
      final first = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      final later = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      var refreshes = 0;
      when(() => nfse.refresh(_billedId)).thenAnswer((_) => ++refreshes == 1 ? first.future : later.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).fiscal, _voice);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_billedId));
      await pumpEventQueue();
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));            // o initState da página recriada
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
      final at = states.length;
      first.complete(const Left(Failure(message: 'em uso', statusCode: 409, code: 'RESOURCE_BUSY')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.sublist(at).whereType<ServiceOrderActionFailure>(), hasLength(1), reason: 'o desfecho do ato aparece (one-shot)');
      expect(states.sublist(at).whereType<ServiceOrderDetailState>(), isEmpty, reason: 'o detalhe NÃO volta por cima da lista');
      final shown = _shown(states) as ServiceOrderListState;
      expect([shown.loading, refreshes, later.isCompleted], [false, 1, false]);
    });

    test('[CORRIGIDO R10-ADV-03, a VOZ DE OUTRA OS — era o FATO] o mesmo ramo da falha com o operador abrindo OUTRA OS no meio: "Consultar" na OS A (AUTORIZADA — a consulta vai ao fisco e pode demorar), a página recriada mostra a lista, o operador abre a OS B (RECUSADA, com Transmitir) e ela carrega; a consulta de A falha → o detalhe CAPTURADO de A voltava por cima de B com a voz e o efeito que o bloc guarda AGORA — os de B: cabeçalho de A, seção "No fisco" de B (o selo "recusada" e o botão Transmitir numa nota autorizada; o número e a chave de B copiáveis como se fossem de A); e o `_detail` do bloc é B. É a classe do R9-ADV-03 (corrigida só no caminho do `_reloadDetail`)', () async {
      const otherId = 8001;
      const other = ServiceOrderFull(id: otherId, customerId: 2, status: 'F');
      const otherVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 2);
      when(() => repo.getById(otherId)).thenAnswer((_) async => const Right(other));
      when(() => invoice.fiscalEffect(otherId)).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
      when(() => nfse.getView(_billedId)).thenAnswer((_) async => const Right(_voice));
      when(() => nfse.getView(otherId)).thenAnswer((_) async => const Right(otherVoice));
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_billedId)).thenAnswer((_) => refresh.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_billedId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));            // o initState da página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(otherId));                             // o operador abre a OS B
      await pumpEventQueue(times: 20);
      expect([(_shown(states) as ServiceOrderDetailState).order.id, (_shown(states) as ServiceOrderDetailState).fiscal], [otherId, otherVoice]);
      refresh.complete(const Left(NetworkFailure(detail: 'ClientException: Failed to fetch')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final stays = _shown(states) as ServiceOrderDetailState;
      expect([stays.order.id, stays.fiscal], [otherId, otherVoice], reason: 'a tela segue na OS B, com a voz DELA — nada de A volta');
    });

    test('[CORRIGIDO R10-ADV-03 LOW] o mesmo roteiro (ato no detalhe + página recriada no meio + lista que chega depois do detalhe relido + fim do lote): a tela NUNCA termina num spinner sem nada no ar — ou o detalhe (o pedido do ato é anterior ao da lista e perde a vez) ou a lista LIVRE. Correção sugerida: o ato toma a geração no COMEÇO (o `_reloadDetail` do ato recebe a geração de quando o ato foi pedido) — ou o `_detail` só é zerado onde a lista é EMITIDA', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      final item = Completer<Either<Failure, int>>();
      when(() => repo.itemPost(_newId, any())).thenAnswer((_) => item.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      bloc.add(const ServiceOrderItemSaveRequested(orderId: _newId, input: _item));
      await pumpEventQueue();
      final slowList = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) => slowList.future);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue();
      item.complete(const Right(1));
      await pumpEventQueue(times: 20);
      slowList.complete(Right(_page([1, 2])));
      await pumpEventQueue(times: 20);
      listAnswersNow();
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states);
      expect(last is ServiceOrderListState && last.loading, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  // 4. D-F176 — a linha incerta com todos os tipos de Failure
  // ---------------------------------------------------------------------
  group('D-F176 — a linha incerta × os tipos de Failure', () {
    Future<FiscalTransmitBatchReport> batch(Map<int, Failure> by) {
      when(() => nfse.transmit(any())).thenAnswer((inv) async => Left(by[inv.positionalArguments[0] as int]!));
      return ServiceOrderFiscalTransmitBatch(repository: nfse, maxConsecutiveUnknown: 99).call(by.keys.toList());
    }

    /// A linha como a PÁGINA a compõe (`_showFiscalBatchSummary` — cerca abaixo).
    String uncertainLine(FiscalTransmitBatchRow r) =>
        'forms.serviceOrder.fiscalBatchUncertainRow'.tr(args: ['${r.orderId}']) +
        (r.network ? ' (${'forms.serviceOrder.fiscalBatchNoConnection'.tr()})' : r.uncertainDetail);

    test('[RESISTIU] a matriz de falhas de um ato: 502/503/504/408 do proxy sem corpo → "(HTTP N)"; 500 cru → "(HTTP 500)"; 500 INTERNAL com ref → "(INTERNAL · ref X)"; 409 RESOURCE_BUSY → "(RESOURCE_BUSY)"; 2xx fora do envelope → "(CLIENT_INVALID_RESPONSE)"; rede caída (com ou sem detalhe) → "(sem conexão)" e NUNCA o texto da exceção; nenhuma linha com "()"; 401/403/422 não são incertas (recusadas — o 401 e o 403 param o lote); o status HTTP nunca aparece quando há código', () async {
      final r = await batch({
        1: const Failure(message: 'Bad Gateway', statusCode: 502),
        2: const Failure(message: 'gw', statusCode: 503, code: ''),
        3: const Failure(message: 'gw', statusCode: 504),
        4: const Failure(message: 'Request Timeout', statusCode: 408),
        5: const Failure(message: 'core.errors.generic', statusCode: 500),
        6: const Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'ab12cd'),
        7: const Failure(message: 'em uso', statusCode: 409, code: 'RESOURCE_BUSY'),
        8: const Failure(message: 'core.errors.invalidResponse', statusCode: 201, code: ClientFailureCodes.invalidResponse),
        9: const NetworkFailure(detail: 'ClientException: XMLHttpRequest error., uri=https://nfse.example/v1/nfse/invoices/9/transmit'),
        10: const NetworkFailure(),
        11: const Failure(message: 'DPS recusada', statusCode: 422, code: 'E0116'),
      });
      final byId = {for (final row in r.rows) row.orderId: row};
      expect(r.uncertainRows.map((x) => x.orderId).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect([for (final id in [1, 2, 3, 4, 5, 6, 7, 8]) byId[id]!.uncertainDetail], [
        ' (HTTP 502)', ' (HTTP 503)', ' (HTTP 504)', ' (HTTP 408)', ' (HTTP 500)', ' (INTERNAL · ref ab12cd)', ' (RESOURCE_BUSY)',
        ' (${ClientFailureCodes.invalidResponse})',
      ]);
      for (final id in [9, 10]) {
        expect([byId[id]!.network, byId[id]!.supportRef, uncertainLine(byId[id]!).endsWith(' (sem conexão)')], [true, '', true]);
      }
      for (final row in r.uncertainRows) {
        final line = uncertainLine(row);
        expect([line.contains('()'), line.contains('ClientException'), line.contains('XMLHttpRequest')], [false, false, false], reason: line);
      }
      expect(r.refusedRows.map((x) => x.orderId).toList(), [11]);
      final stop = await batch({1: const UnauthorizedFailure(), 2: const Failure(message: 'x', statusCode: 503)});
      expect([stop.uncertain, stop.refused, stop.notTried], [0, 1, 1]);
      final src = File(_pageSrc).readAsStringSync();
      expect(src, contains(r"(r.network ? ' (${'forms.serviceOrder.fiscalBatchNoConnection'.tr()})' : r.uncertainDetail)"));
    });

    test('[FATO — base da Q-F187-ADV-01 (analisado: navegador)] no app WEB, a nfse-api é OUTRA origem (CORS — `corsFor` na nfse-api, origem do build no Plesk): a página 502/503/504 do PROXY da hospedagem não leva `Access-Control-Allow-Origin` e o navegador NÃO entrega a resposta ao app — o `http` do Flutter Web lança `ClientException: XMLHttpRequest error.`, que o `ApiClient` vira `NetworkFailure` (todo erro do envio que não é de configuração). O "HTTP 503" da D-F176 só aparece se o proxy puser CORS na página de erro (ou no Android); no web o operador lê "(sem conexão)" com a rede BOA — o suporte vai atrás da internet do cliente, e o proxy (o caso que motivou a D-F176) some. A frase principal ("resultado incerto — consulte") segue certa', () async {
      final core = File('../../packages/core/lib/src/shared/http/api_client.dart').readAsStringSync();
      expect(core, matches(RegExp(r'\} catch \(e\) \{\s*throw NetworkFailure\(detail: e\.toString\(\)\);')));
      final r = await batch({1: const NetworkFailure(detail: 'ClientException: XMLHttpRequest error., uri=https://nfse.setes.example/v1/nfse/invoices/1/transmit')});
      expect(uncertainLine(r.rows.single), 'Ordem 1: resultado incerto — consulte a situação no fisco antes de transmitir de novo (sem conexão)');
    });

    test('[FATO — base da Q-F187-ADV-02] a D-F176 tirou da linha o texto da exceção da REDE, mas a outra falha cujo `supportRef` é texto cru do Dart segue na tela: a resposta 2xx que o datasource não lê (`invalidResponseFailure` no `_guard` do repositório — F2B-ADV-12) é incerta e a linha leva o erro do Dart como "ref"', () async {
      final r = await batch({1: invalidResponseFailure("type 'int' is not a subtype of type 'String?' in type cast")});
      expect(r.rows.single.uncertainDetail,
          " (${ClientFailureCodes.invalidResponse} · ref type 'int' is not a subtype of type 'String?' in type cast)");
    });
  });

  // ---------------------------------------------------------------------
  // 5. Sequências que RESISTIRAM
  // ---------------------------------------------------------------------
  group('sequências de eventos que resistiram', () {
    test('[RESISTIU] PÁGINA RECUADA × ver OS: a página 3 volta vazia (o lote tirou as OS) → o bloc recua para a última página (2ª carga, nova geração); o operador abre uma OS NO MEIO; a 2ª carga chega depois — descartada; a tela termina no detalhe, sem loading preso', () async {
      final second = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) {
        listCalls++;
        final page = inv.namedArguments[#page] as int;
        if (page == 3) return Future.value(Right(_page(const [], page: 3, total: 12)));
        return second.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(page: 3));
      await pumpEventQueue(times: 20);
      expect(listCalls, 2, reason: 'recuou para a última página');
      bloc.add(const ServiceOrderViewRequested(_newId));
      await pumpEventQueue(times: 20);
      second.complete(Right(_page([1, 2], page: 2, total: 12)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
    });

    test('[RESISTIU] a marca "a caminho" que FICA para trás não prende nada: o POST do FAB é superado por uma troca de aba (o detalhe dele é descartado ao chegar — `_pendingDetailScreen` fica com o número velho); depois o fim de um lote e de uma rotina mensal RECARREGAM (a marca velha nunca é igual à geração de agora) — a lista termina LIVRE', () async {
      final post = Completer<Either<Failure, int>>();
      when(() => repo.open(5)).thenAnswer((_) => post.future);
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) async => const Right(MonthlyRunReport(processed: 1)));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      post.complete(const Right(_newId));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderDetailState>(), isEmpty, reason: 'o detalhe superado não aparece');
      final before = listCalls;
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      expect([listCalls, (_shown(states) as ServiceOrderListState).loading], [before + 1, false]);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([listCalls, (_shown(states) as ServiceOrderListState).loading], [before + 2, false]);
    });

    test('[RESISTIU] o lote fiscal termina com o detalhe A CAMINHO (FAB) e o GET dele FALHA depois: o fim respeitou o detalhe (só o relatório), a falha do GET recarrega — a lista termina LIVRE, nada preso', () async {
      final get = Completer<Either<Failure, ServiceOrderFull>>();
      when(() => repo.getById(_newId)).thenAnswer((_) => get.future);
      when(() => nfse.transmit(any())).thenAnswer((_) async => const Right(ServiceOrderTransmitResult(invoiceId: 1, attempt: 1, accessKey: 'K')));
      final gate = Completer<void>();
      when(() => nfse.transmit(1)).thenAnswer((_) async {
        await gate.future;
        return const Right(ServiceOrderTransmitResult(invoiceId: 1, attempt: 1, accessKey: 'K'));
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue(times: 20);
      final before = listCalls;
      gate.complete();
      await pumpEventQueue(times: 20);
      expect([states.whereType<ServiceOrderFiscalBatchDone>().length, listCalls], [1, before], reason: 'a caminho = só o relatório');
      get.complete(const Left(Failure(message: 'x', statusCode: 500)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([listCalls, (_shown(states) as ServiceOrderListState).loading], [before + 1, false]);
    });

    test('[RESISTIU] a rotina mensal FALHA (403 sem privilégio) com a OS do FAB aberta: a falha vai à ponte e o operador FICA na OS (D-F177 também no ramo da falha); voltar à lista recarrega livre', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) => run.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      await openByFab(bloc, states);
      final before = listCalls;
      run.complete(const Left(Failure(message: 'Sem privilégio', statusCode: 403)));
      await pumpEventQueue(times: 20);
      expect([states.whereType<ServiceOrderActionFailure>().length, _shown(states) is ServiceOrderDetailState, listCalls], [1, true, before]);
      bloc.add(const ServiceOrderBackToListPressed());
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([listCalls, (_shown(states) as ServiceOrderListState).loading], [before + 1, false]);
    });

    test('[RESISTIU] critério RECUSADO no spinner do lote (a pesquisa avançada fica ativa no loading): o critério sai com aviso, a recarga refeita sai em loading (o lote segue — D-F169), o FAB abre a OS no meio e o fim do lote fica no detalhe; voltar recarrega livre', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      const refused = Failure(message: 'critério inválido', statusCode: 400, code: 'SEARCH_CRITERION_INVALID',
          fields: [FailureField(field: 'city', message: 'cidade inexistente')]);
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        listCalls++;
        final c = inv.namedArguments[#criteria] as SearchCriteriaValues;
        return c.values.containsKey('city') ? const Left(refused) : Right(_page([1]));
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(criteria: SearchCriteriaValues({'city': 'X'})));
      await pumpEventQueue(times: 20);
      expect([listCalls, (_shown(states) as ServiceOrderListState).loading, (_shown(states) as ServiceOrderListState).criteria.isEmpty], [2, true, true]);
      await openByFab(bloc, states);
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      expect(_shown(states), isA<ServiceOrderDetailState>());
      bloc.add(const ServiceOrderBackToListPressed());
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
    });
  });
}
