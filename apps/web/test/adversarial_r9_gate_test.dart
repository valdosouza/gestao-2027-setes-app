// GATE ADVERSARIAL do DELTA da Rodada 9 da F2a/F2b (setes-app) — alvo: commit
// 3766f39 (delta sobre 13cdd92): D-F174 (entrar no detalhe incrementa a geração
// da lista — a recarga em voo não emite por cima; o fim de um lote com uma OS
// aberta mostra o relatório e NÃO recarrega a lista), a linha incerta sem "()"
// quando não há código nem ref (R8-SOC-02 a) e "o lote parou" só quando sobrou
// nota (R8-SOC-02 — a 3ª incerta na última nota não para).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R9-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r9_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre) — cada ACHADO
//     tem o seu FATO, que é a PROVA executável de hoje.
// Nada aqui fala com servidor: repositórios mocktail. No app, durante um lote a
// lista fica SEMPRE em loading (D-F169 — o corpo é o spinner), então a única
// porta para o detalhe no meio de um lote é o FAB "Abrir OS" (ativo no
// loading): é por ela que os ataques do D-F174 entram.

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
const _tx = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');
const _busy = Failure(message: 'Registro em uso por outra operação — tente novamente', statusCode: 409, code: 'RESOURCE_BUSY');
const _proxy503 = Failure(message: 'Service Unavailable', statusCode: 503);

/// A OS NOVA que o FAB abre (aberta — sem seção fiscal) e uma OS FATURADA (com a seção "No fisco": voz + efeito).
const _newId = 77;
const _newOrder = ServiceOrderFull(id: _newId, customerId: 5);
const _billedId = 7374;
const _billed = ServiceOrderFull(id: _billedId, customerId: 1, status: 'F');
const _voice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';
const _blocSrc = 'lib/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

BatchInvoiceReport _okReport(List<int> ids) =>
    BatchInvoiceReport.fromEntries([for (final id in ids) BatchInvoiceEntry(orderId: id, ok: true)]);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState _shown(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).last;

/// As provas do comportamento de ANTES de uma correção ficam como história, puladas (o skip diz por quê).
void _superseded(String description, dynamic Function() body) =>
    test(description, body, skip: 'SUPERADO — prova do comportamento de antes da correção (R9-SOC-04/R9-ADV-01…03)');

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
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    listCalls = 0;
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async {
      listCalls++;
      return const Right(PagedResult(items: [], page: 1, pageSize: 10, total: 0));
    });
    when(() => repo.open(5)).thenAnswer((_) async => const Right(_newId));
    when(() => repo.getById(_newId)).thenAnswer((_) async => const Right(_newOrder));
    when(() => repo.getById(_billedId)).thenAnswer((_) async => const Right(_billed));
    when(() => invoice.fiscalEffect(_billedId)).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  /// Bloc + lista de estados + "abre a OS NOVA pelo FAB" (lookup → POST → detalhe).
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
  // 1. D-F174 — o lote de FATURAMENTO e o detalhe aberto pelo FAB
  // ---------------------------------------------------------------------
  group('D-F174 × lote de faturamento', () {
    test('[CORRIGIDO R9-ADV-01 LOW — contador único da tela + a voz gravada com o detalhe] o 1º BLOCO do lote de faturamento falha INTEIRO (409 RESOURCE_BUSY sob contenção, 500, rede — o bloco de 50 ordens é o que mais demora: 22 s/ordem sob trava, Q-R5.1) com a OS aberta pelo FAB no meio: o fim do lote mostra a falha e RECARREGA a lista — tira o operador do detalhe. O ramo "1º bloco falhou, nada faturado" (`_runBatch`, `failure != null && parts.length == 1`) não passou pela guarda nova `if (_detail != null) return;` da D-F174 ("o fim de um lote (faturamento ou fiscal) com uma OS aberta … não recarrega a lista"). Correção sugerida: a mesma guarda no ramo da falha (a falha vai à ponte; voltar à lista recarrega)', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      chunk.complete(const Left(_busy));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderActionFailure>().map((s) => s.failure.code), ['RESOURCE_BUSY'], reason: 'a falha sai');
      expect(_shown(states), isA<ServiceOrderDetailState>(), reason: 'o operador segue na OS que abriu (D-F174)');
    });

    _superseded('[SUPERADO pela correção — era a prova do R9-ADV-01] hoje: 1º bloco falha inteiro com a OS do FAB aberta → falha + recarga da lista → a tela volta à LISTA (o detalhe some) — o mesmo lote terminando BEM deixa o operador no detalhe (D-F174)', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      final before = listCalls;
      chunk.complete(const Left(_busy));
      await pumpEventQueue(times: 20);
      expect(_shown(states), isA<ServiceOrderListState>());
      expect(listCalls, before + 1, reason: 'a recarga que a D-F174 suprime no fim BEM-sucedido aconteceu');
      // o contraste: o MESMO lote terminando com relatório não tira do detalhe
      final ok = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => ok.future);
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      ok.complete(Right(_okReport([1, 2])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(_shown(states), isA<ServiceOrderDetailState>());
    });

    test('[RESISTIU] FAB no meio do lote → detalhe da OS nova; o lote termina com relatório: o relatório sai UMA vez, a tela fica no detalhe, NENHUMA recarga da lista acontece; "Voltar" recarrega e a lista sai SEM loading (nada preso) — e o 2º bloco (lote de 60 → 2 blocos) também é aguardado sem derrubar o detalhe', () async {
      final chunks = <Completer<Either<Failure, BatchInvoiceReport>>>[];
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) {
        final c = Completer<Either<Failure, BatchInvoiceReport>>();
        chunks.add(c);
        return c.future;
      });
      final (bloc, states, sub) = await start();
      final ids = [for (var i = 1; i <= 60; i++) i];
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: ids, input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      final before = listCalls;
      chunks[0].complete(Right(_okReport(ids.sublist(0, 50))));
      await pumpEventQueue();
      expect(chunks, hasLength(2));
      expect(_shown(states), isA<ServiceOrderDetailState>());
      chunks[1].complete(Right(_okReport(ids.sublist(50))));
      await pumpEventQueue(times: 20);
      expect(states.whereType<ServiceOrderBatchInvoiceDone>().single.report.invoiced, 60);
      expect([_shown(states) is ServiceOrderDetailState, listCalls], [true, before]);
      bloc.add(const ServiceOrderBackToListPressed());
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states) as ServiceOrderListState;
      expect([last.loading, listCalls], [false, before + 1]);
    });

    test('[RESISTIU] o lote termina enquanto o POST do FAB está no ar (o detalhe ainda não existe): o fim recarrega a lista (`_detail` nulo), e o detalhe que chega DEPOIS vence — a tela termina na OS nova, sem loading preso', () async {
      final post = Completer<Either<Failure, int>>();
      when(() => repo.open(5)).thenAnswer((_) => post.future);
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async => Right(_okReport([1])));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue(times: 20);
      expect(_shown(states), isA<ServiceOrderListState>());
      post.complete(const Right(_newId));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
    });

    test('[RESISTIU] o lote termina com o GET do detalhe no ar (`_detail` ainda nulo → o fim pede a lista) e a lista responde DEPOIS do detalhe: a geração da D-F174 descarta a lista — a tela termina no detalhe', () async {
      final get = Completer<Either<Failure, ServiceOrderFull>>();
      when(() => repo.getById(_newId)).thenAnswer((_) => get.future);
      final list = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async => Right(_okReport([1])));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue();
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) => list.future);
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue(times: 20);
      get.complete(const Right(_newOrder));
      await pumpEventQueue();
      list.complete(const Right(PagedResult(items: [ServiceOrderListItem(id: 1, customerId: 1)], page: 1, pageSize: 10, total: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
    });

    test('[RESISTIU] erro ao abrir (POST ok, GET do detalhe 500) no meio do lote: a falha vai à ponte e a lista volta EM LOADING (o lote segue — D-F169); o fim do lote (sem detalhe) recarrega e a lista sai LIVRE — nada preso', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      when(() => repo.getById(_newId)).thenAnswer((_) async => const Left(Failure(message: 'x', statusCode: 500)));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue);
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
    });

    test('[RESISTIU] FATURAR a OS nova (individual) pelo detalhe com o lote no ar: vai à aba Faturadas EM LOADING (o lote segue); o fim do lote, sem detalhe, recarrega — Faturadas livre', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      when(() => repo.invoice(_newId, any())).thenAnswer((_) async => const Right(ServiceOrderInvoiceResult(invoiceNumber: '9')));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      bloc.add(const ServiceOrderInvoiceRequested(orderId: _newId, input: _input));
      await pumpEventQueue(times: 20);
      expect([(_shown(states) as ServiceOrderListState).loading, (_shown(states) as ServiceOrderListState).status], [true, 'F']);
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states) as ServiceOrderListState;
      expect([last.loading, last.status], [false, 'F']);
    });

    test('[RESISTIU] a tela SAIU (stopBatches — o onDispose do módulo) com o detalhe aberto: o lote para sem relatório e sem recarga; o detalhe não é tocado', () async {
      final chunk = Completer<Either<Failure, BatchInvoiceReport>>();
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => chunk.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));
      await pumpEventQueue();
      await openByFab(bloc, states);
      final before = listCalls;
      bloc.stopBatches();
      chunk.complete(Right(_okReport([1])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([states.whereType<ServiceOrderBatchInvoiceDone>().length, listCalls, _shown(states) is ServiceOrderDetailState], [0, before, true]);
    });
  });

  // ---------------------------------------------------------------------
  // 2. D-F174 — o lote FISCAL e os outros "fins" que recarregam a lista
  // ---------------------------------------------------------------------
  group('D-F174 × lote fiscal, rotina mensal e o passo 1 do lote fiscal', () {
    test('[RESISTIU] FAB no meio do lote FISCAL (a porta real — a lista do lote é spinner): o fim mostra o relatório, fica no detalhe sem recarregar; CANCELAR a OS nova (DELETE) pelo detalhe com o lote no ar volta à lista EM LOADING; o fim (sem detalhe) recarrega e a lista sai livre', () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gate.future;
        return const Right(_tx);
      });
      when(() => repo.cancel(_newId)).thenAnswer((_) async => const Right(unit));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      await pumpEventQueue();
      await openByFab(bloc, states);
      final second = Completer<void>();
      // 1º lote: termina com o detalhe aberto
      gate.complete();
      await pumpEventQueue(times: 20);
      expect([states.whereType<ServiceOrderFiscalBatchDone>().length, _shown(states) is ServiceOrderDetailState], [1, true]);
      // 2º lote: o operador cancela a OS nova no meio
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await second.future;
        return const Right(_tx);
      });
      bloc.add(const ServiceOrderBackToListPressed());
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([3]));
      await pumpEventQueue();
      await openByFab(bloc, states);
      bloc.add(const ServiceOrderCancelRequested(_newId));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue);
      second.complete();
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
    });

    test('[DECIDIDO D-F177 (= Q-F185 (a)) — era o FATO base da Q-F185-ADV-01] a ROTINA MENSAL (o botão não é travado pelo loading — pode levar minutos com N contratos) e o PASSO 1 do lote fiscal ("Transmitir pendentes" — a fotografia lê TODAS as páginas da nfse-api) recarregam a lista no fim SEM olhar o detalhe: com a OS do FAB aberta no meio, o operador volta à lista. No passo 1 o diálogo "N notas sem NFS-e — transmitir agora?" abre por cima do DETALHE e, enquanto ele está aberto, a tela troca para a lista. Não são "lote" na letra da D-F174 (faturamento ou fiscal), mas são o mesmo caso', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) => run.future);
      final pending = Completer<Either<Failure, PagedResult<ServiceOrderFiscalPending>>>();
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => pending.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      await openByFab(bloc, states);
      run.complete(const Right(MonthlyRunReport(processed: 3, opened: 3)));
      await pumpEventQueue(times: 20);
      expect([states.whereType<ServiceOrderMonthlyRunDone>().length, _shown(states) is ServiceOrderDetailState], [1, true]);   // D-F177: fica na OS
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue();
      await openByFab(bloc, states);
      final at = states.length;
      pending.complete(const Right(PagedResult(items: [ServiceOrderFiscalPending(invoiceId: 9)], page: 1, pageSize: 100, total: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final after = states.sublist(at);
      final ask = after.indexWhere((s) => s is ServiceOrderFiscalPendingLoaded);
      expect(ask, greaterThanOrEqualTo(0));
      expect(after.take(ask).any((s) => s is ServiceOrderListState), isFalse, reason: 'o diálogo abre por cima do detalhe');
      expect(_shown(states), isA<ServiceOrderDetailState>(), reason: 'D-F177: e a tela FICA no detalhe (a confirmação abre por cima dele)');
    });
  });

  // ---------------------------------------------------------------------
  // 3. D-F174 — a geração só num sentido: o detalhe que chega tarde
  // ---------------------------------------------------------------------
  group('D-F174 — a carga do detalhe que chega DEPOIS de outra escolha do operador', () {
    test('[CORRIGIDO R9-ADV-02 LOW — contador único da tela + a voz gravada com o detalhe] ver uma OS FATURADA com a nfse-api lenta (a seção "No fisco" espera a voz) e, no spinner, trocar de ABA (as abas, o filtro e a barra continuam ativos no loading): o `_reloadList` da aba ZERA o `_detail`, a lista da aba aparece — e o detalhe, quando a voz chega, emite por cima mesmo assim (a geração da D-F174 só invalida LISTA; a carga do detalhe não confere nada). A tela mostra a OS com `_detail == null`: as ações dela não emitem o `saving` (os botões não travam — 2º clique de Consultar/Reconferir manda de novo) e, no lote, a guarda `_detail != null` da D-F174 não vale. O certo: a escolha DEPOIS (a aba) vence a carga abandonada, ou o detalhe que emite é o mesmo que o bloc guarda — nunca um detalhe na tela com o `_detail` nulo', () async {
      final voice = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => nfse.getView(_billedId)).thenAnswer((_) => voice.future);
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_billedId)).thenAnswer((_) => refresh.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A'));                                // a aba, no spinner
      await pumpEventQueue(times: 20);
      voice.complete(const Right(_voice));
      await pumpEventQueue(times: 20);
      final at = states.length;
      bloc.add(const ServiceOrderFiscalRefreshRequested(_billedId));                          // "Consultar"
      await pumpEventQueue(times: 20);
      refresh.complete(const Left(_proxy503));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final shown = _shown(states);
      final coherent = shown is ServiceOrderListState ||
          states.sublist(at).any((s) => s is ServiceOrderDetailState && s.saving);
      expect(coherent, isTrue, reason: 'ou a aba venceu, ou o detalhe na tela é o que o bloc guarda (o "Consultar" trava a tela)');
    });

    _superseded('[SUPERADO pela correção — era a prova do R9-ADV-02] hoje: a aba pedida APARECE (lista carregada) e o detalhe da faturada a substitui quando a voz chega; o "Consultar" nessa tela não emite NENHUM estado de `saving` (o `_detail` é nulo) — os botões da seção não travam durante a ida à nfse-api', () async {
      final voice = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => nfse.getView(_billedId)).thenAnswer((_) => voice.future);
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_billedId)).thenAnswer((_) => refresh.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A'));
      await pumpEventQueue(times: 20);
      final tab = _shown(states);
      expect([tab is ServiceOrderListState, (tab as ServiceOrderListState).loading], [true, false], reason: 'a aba apareceu');
      voice.complete(const Right(_voice));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _billedId, reason: 'e o detalhe abandonado a substituiu');
      final at = states.length;
      bloc.add(const ServiceOrderFiscalRefreshRequested(_billedId));
      await pumpEventQueue(times: 20);
      expect(states.sublist(at).whereType<ServiceOrderDetailState>().where((s) => s.saving), isEmpty, reason: 'sem saving: os botões não travam');
      bloc.add(const ServiceOrderFiscalRefreshRequested(_billedId));                          // o 2º clique passa
      await pumpEventQueue(times: 20);
      refresh.complete(const Left(_proxy503));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      verify(() => nfse.refresh(_billedId)).called(2);
    });

    test('[CORRIGIDO R9-ADV-03 LOW — contador único da tela + a voz gravada com o detalhe] DETALHE VELHO: ver a OS FATURADA A (a voz da nfse-api demora — nfse-api fora até o timeout) e, no spinner, abrir uma OS NOVA pelo FAB: o operador entra na OS nova e começa a trabalhar; quando a voz de A chega, a tela PULA para A (a carga abandonada emite por cima — nada a invalida). E o estado fica MISTO: o bloc guarda a OS nova como `_detail` e a voz de A em `_fiscal` — a 1ª ação na tela de A (Consultar) re-emite o detalhe da OS NOVA com a seção fiscal de A. O certo: a carga de detalhe superada por outra navegação não emite', () async {
      final voice = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => nfse.getView(_billedId)).thenAnswer((_) => voice.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue();
      await openByFab(bloc, states);
      voice.complete(const Right(_voice));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId, reason: 'a OS que o operador abriu por último');
    });

    _superseded('[SUPERADO pela correção — era a prova do R9-ADV-03] hoje: a tela pula da OS nova para a faturada A quando a voz de A chega; e o "Consultar" de A re-emite (saving) o detalhe da OS NOVA carregando a voz de A — o estado misto', () async {
      final voice = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => nfse.getView(_billedId)).thenAnswer((_) => voice.future);
      final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      when(() => nfse.refresh(_billedId)).thenAnswer((_) => refresh.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_billedId));
      await pumpEventQueue();
      await openByFab(bloc, states);
      voice.complete(const Right(_voice));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _billedId, reason: 'a tela pulou para A');
      final at = states.length;
      bloc.add(const ServiceOrderFiscalRefreshRequested(_billedId));
      await pumpEventQueue(times: 20);
      final saving = states.sublist(at).whereType<ServiceOrderDetailState>().firstWhere((s) => s.saving);
      expect([saving.order.id, saving.fiscal], [_newId, _voice], reason: 'a OS NOVA com a voz de A');
      refresh.complete(const Left(_proxy503));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
    });

    _superseded('[SUPERADO pela correção — era a prova do R9-ADV-03, a variante VISÍVEL] duas FATURADAS: ver A (a voz demora — A está "recusada", com Transmitir), trocar de aba no spinner, ver B (autorizada, carrega rápido); a voz de A chega e a tela pula para A; o "Consultar" de A falha (503) e a tela termina com o CABEÇALHO e os itens de B e a seção "No fisco" de A, botões LIVRES — o Transmitir da seção (que vem do estado de A) manda `ServiceOrderTransmitRequested(state.order.id)` = B. Hoje o servidor segura (B autorizada → a nfse-api recusa; os planos de cancelamento/manter são relidos no ERP pela OS de B), mas a tela informa a OS errada', () async {
      const aId = 7375;
      const a = ServiceOrderFull(id: aId, customerId: 2, status: 'F');
      const aVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
      final slow = Completer<Either<Failure, ServiceOrderFiscalView>>();
      when(() => repo.getById(aId)).thenAnswer((_) async => const Right(a));
      when(() => nfse.getView(aId)).thenAnswer((_) => slow.future);
      when(() => invoice.fiscalEffect(aId)).thenAnswer((_) async => const Right(ServiceOrderFiscalEffect()));
      when(() => nfse.getView(_billedId)).thenAnswer((_) async => const Right(_voice));
      when(() => nfse.refresh(aId)).thenAnswer((_) async => const Left(_proxy503));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F'));                                // a aba, no spinner
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_billedId));                                   // B, da lista que apareceu
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _billedId);
      slow.complete(const Right(aVoice));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, aId, reason: 'pulou para A');
      bloc.add(const ServiceOrderFiscalRefreshRequested(aId));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states) as ServiceOrderDetailState;
      expect([last.order.id, last.order.isOpen, last.fiscal, last.saving, last.fiscal!.canTransmitState], [_billedId, false, aVoice, false, true]);
      expect(File(_pageSrc).readAsStringSync(), matches(RegExp(r'onTransmit: \(\) =>\s*_bloc\.add\(ServiceOrderTransmitRequested\(state\.order\.id\)\),')));
    });

    test('[FATO — limite conhecido da D-F160 (item de UX do shell)] a página RECRIADA (cruzar 1100 px) com o operador NO DETALHE: o `initState` manda `ListRequested(status: \'A\', filter: \'\')` sem olhar o estado — o bloc (que sobrevive) volta à lista Abertas, filtro e página zerados. Com um lote no ar e a OS do FAB aberta, o resize já derruba o detalhe antes do fim (que então recarrega, por `_detail` nulo). A D-F174 não cobre (não é recarga "em voo"); a D-F160 deixou a perda de estado no resize como item próprio', () async {
      final src = File(_pageSrc).readAsStringSync();
      expect(src, matches(RegExp(r"_bloc = Modular\.get<ServiceOrderBloc>\(\)\s*\.\.add\(const ServiceOrderListRequested\(status: 'A', filter: ''\)\);")));
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gate.future;
        return const Right(_tx);
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: 'abc'));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1]));
      await pumpEventQueue();
      await openByFab(bloc, states);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                   // o initState da página recriada
      await pumpEventQueue(times: 20);
      final resized = _shown(states) as ServiceOrderListState;
      expect([resized.status, resized.filter, resized.loading], ['A', '', true]);
      gate.complete();
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
    });

    test('[RESISTIU] ver OS → o GET do detalhe FALHA com uma lista em voo (a da aba, lenta): a recarga do erro é NOVA (geração seguinte) e a velha é descartada — a tela termina na lista da recarga, sem loading preso', () async {
      final calls = <Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>>[];
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        final c = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
        calls.add(c);
        return c.future;
      });
      when(() => repo.getById(9)).thenAnswer((_) async => const Left(Failure(message: 'Não encontrada', statusCode: 404)));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue();
      bloc.add(const ServiceOrderViewRequested(9));
      await pumpEventQueue();
      expect(calls, hasLength(2));
      calls[1].complete(const Right(PagedResult(items: [ServiceOrderListItem(id: 2, customerId: 1)], page: 1, pageSize: 10, total: 1)));
      await pumpEventQueue();
      calls[0].complete(const Right(PagedResult(items: [ServiceOrderListItem(id: 1, customerId: 1)], page: 1, pageSize: 10, total: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = _shown(states) as ServiceOrderListState;
      expect([last.loading, last.items.single.id], [false, 2]);
    });

    test('[CORRIGIDO — cerca do fonte] a guarda da D-F174 (`_onDetail` — aberto OU a caminho) nos TRÊS fins de lote (faturamento ok, 1º bloco que falha — R9-ADV-01 — e fiscal); UM contador da tela; o `_detail` e a voz gravados JUNTOS depois da conferência do pedido (R9-ADV-03)', () {
      final src = File(_blocSrc).readAsStringSync();
      expect(RegExp(r'if \(_onDetail\) return;').allMatches(src).length, 7);   // + D-F177: rotina mensal (2) e pendentes (2)
      expect(src, isNot(contains('_listGeneration')));
      // R10-SOC-03: a conferência do pedido virou `live()` (o contador e, num ato, o detalhe ainda aberto)
      expect(src, matches(RegExp(r'final fiscal = await _fetchFiscal\(full\);\s*if \(!live\(\)\) return;')));
      // D-F187: entre o `_detail` e a emissão, só o registro do número que a tela mostra
      expect(src, matches(RegExp(r'_effectFailure = fiscal\.effectFailure;\s*_detail = full;\s*_shownNumbers\[full\.id\] = full\.number \?\? full\.id;[^\n]*\n\s*emit\(_detailState\(full\)\);')));
      expect(src, matches(RegExp(r'if \(failure != null && parts\.length == 1\) \{[^}]*if \(_onDetail\) return;\s*await _reloadList\(emit\);')));
    });
  });

  // ---------------------------------------------------------------------
  // 4. A parada do lote fiscal e a linha incerta (R8-SOC-02)
  // ---------------------------------------------------------------------
  group('R8-SOC-02 — a parada e a linha incerta', () {
    Future<FiscalTransmitBatchReport> usecase(Map<int, Either<Failure, ServiceOrderTransmitResult>> by, List<int> ids,
        {int max = 3, bool Function()? stop}) {
      when(() => nfse.transmit(any())).thenAnswer((inv) async => by[inv.positionalArguments[0] as int]!);
      return ServiceOrderFiscalTransmitBatch(repository: nfse, maxConsecutiveUnknown: max).call(ids, shouldStop: stop);
    }

    test('[RESISTIU] UMA nota só: incerta = 1 incerta, sem parada, sem não tentadas; recusa = 1 recusada; SISTÊMICA = "parou: <causa>" sem nenhuma não tentada (decidido no R8: a frase informa a causa — certificado, privilégio)', () async {
      final u = await usecase({1: const Left(_proxy503)}, [1]);
      expect([u.uncertain, u.notTried, u.stoppedBy], [1, 0, null]);
      final r = await usecase({1: const Left(Failure(message: 'Rejeitada', statusCode: 422, code: 'FISCAL_DPS_REJECTED'))}, [1]);
      expect([r.refused, r.notTried, r.stoppedBy], [1, 0, null]);
      final s = await usecase({1: const Left(Failure(message: 'A1 vencido', statusCode: 422, code: 'FISCAL_CERT_EXPIRED'))}, [1]);
      expect([s.refused, s.notTried, s.stoppedBy?.code], [1, 0, 'FISCAL_CERT_EXPIRED']);
      expect('forms.serviceOrder.fiscalBatchStopped'.tr(args: [s.stoppedBy!.message]), 'O lote parou: A1 vencido');
    });

    test('[RESISTIU] a contagem da parada é por SEQUÊNCIA: incerta·incerta·OK·incerta·incerta·incerta(última) = 5 incertas, sem parada; incerta·incerta·incerta·OK = parou na 3ª, 1 não tentada; ids repetidos contam uma vez (o "sobrou nota" olha a lista SEM repetição: [1,2,3,3] com 3 incertas não para)', () async {
      const ok = Right<Failure, ServiceOrderTransmitResult>(_tx);
      final a = await usecase({1: const Left(_proxy503), 2: const Left(_proxy503), 3: ok, 4: const Left(_proxy503), 5: const Left(_proxy503), 6: const Left(_proxy503)}, [1, 2, 3, 4, 5, 6]);
      expect([a.uncertain, a.transmitted, a.notTried, a.stoppedBy], [5, 1, 0, null]);
      final b = await usecase({1: const Left(_proxy503), 2: const Left(_proxy503), 3: const Left(_proxy503), 4: ok}, [1, 2, 3, 4]);
      expect([b.uncertain, b.notTried, b.notTriedRows.single.orderId, b.stoppedBy?.statusCode], [3, 1, 4, 503]);
      final c = await usecase({1: const Left(_proxy503), 2: const Left(_proxy503), 3: const Left(_proxy503)}, [1, 2, 3, 3]);
      expect([c.uncertain, c.notTried, c.stoppedBy, c.requested], [3, 0, null, 3]);
    });

    test('[RESISTIU] a tela SAIU (shouldStop) na 3ª incerta: o lote para SEM relatório de parada (nenhuma não tentada inventada) — o bloc nem emite o relatório (tela fechada)', () async {
      var n = 0;
      final r = await usecase({1: const Left(_proxy503), 2: const Left(_proxy503), 3: const Left(_proxy503), 4: const Left(_proxy503)}, [1, 2, 3, 4],
          stop: () => ++n > 2);
      expect([r.uncertain, r.notTried, r.stoppedBy], [2, 0, null]);
    });

    test('[RESISTIU] o complemento da linha incerta só com conteúdo — sem código e sem ref: nada; só ref: " (ref X)"; só código: " (CÓDIGO)"; os dois: " (CÓDIGO · ref X)"; as DUAS línguas com UMA lacuna e nenhum chamador passando 2 argumentos', () {
      String d(String code, String ref) => FiscalTransmitBatchRow(orderId: 1, ok: false, code: code, unknown: true, supportRef: ref).uncertainDetail;
      expect([d('', ''), d('', 'r1'), d('RESOURCE_BUSY', ''), d('INTERNAL', 'ab12')], ['', ' (ref r1)', ' (RESOURCE_BUSY)', ' (INTERNAL · ref ab12)']);
      for (final lang in ['pt', 'en']) {
        final row = ((_load(lang)['forms'] as Map)['serviceOrder'] as Map)['fiscalBatchUncertainRow'] as String;
        expect(RegExp(r'\{\}').allMatches(row).length, 1, reason: lang);
        expect(row.trimRight().endsWith(')'), isFalse, reason: '$lang: a frase não traz mais "(…)" fixo');
      }
      final callers = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('fiscalBatchUncertainRow')).toList();
      expect(callers, hasLength(1));
      final caller = callers.single.readAsStringSync();
      expect(caller, contains(r"'forms.serviceOrder.fiscalBatchUncertainRow'.tr(args: [note(r.orderId)]) +"));   // D-F187: o nº da nota
      expect(caller, contains(r"(r.network ? ' (${'forms.serviceOrder.fiscalBatchNoResponse'.tr()})' : r.uncertainDetail)"));   // D-F176
    });
  });
}
