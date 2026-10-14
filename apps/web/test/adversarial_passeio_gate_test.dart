// GATE ADVERSARIAL independente do PASSEIO LOGADO da F2b (setes-app) — alvo: `570324c..f312f06` (branch f2b, commit f312f06):
//   - D-F204 (= D-F188): `core.errors.network` NEUTRO no app inteiro (pt/en);
//   - D-F205 (= P-01 (a)): a falha de rede leva o código CURTO do serviço (`NETWORK · setes-api` / `NETWORK · nfse-api` — `serviceLabel`
//     no `ProductApiClient`, `networkFailureCode`); a exceção crua do Dart (com a URL) só no `developer.log`;
//   - D-F206 (= P-03 (a)): a falha de CARGA da lista de OS é estado próprio (`ServiceOrderListState.loadFailed`) + "Tentar novamente";
//   - P-04: `fields[]` sem âncora na página de OS → a mensagem PRINCIPAL junto da do campo.
//
// O que o delta PROMETE e este gate ataca: (i) toda emissão de lista que não é a falha da carga sai com `loadFailed: false` (lote por cima,
// fim de lote, rotina mensal, pendentes, troca de aba, filtro, página, critérios, volta do detalhe, recarga depois de faturar/cancelar);
// a falha da carga sai SEMPRE como `loadFailed` (nunca "lista vazia") com o `loading` do lote no ar (D-F169); o "Tentar novamente" refaz o
// MESMO pedido; (ii) nenhuma falha de rede de `ApiClient`/`NfseApiClient` (get/post/put/delete, token de seleção, `sessionAlive`) leva URL
// ou texto do Dart à tela, e a classificação do ato fiscal (desconhecido — D-F139/D-F176) e do 401 (D-F148) não mudou; (iii) o texto
// final do P-04 nas formas REAIS dos produtores (setes-api 400 DTO, nfse-api 422 FISCAL_DPS_INVALID, 409 com fields[]).
//
// Convenção do gate (a mesma dos gates R5–R16):
//   - `[ACHADO PSO-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_passeio_gate_test.dart
//   - `[FATO PSO-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada achado/limite.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail, e o `ApiClient`/`NfseApiClient` DE VERDADE sobre o `MockClient` do package:http
// (a rede "cai" lançando a exceção que o navegador produz). A página de OS é montada de verdade (Modular com binds de teste).
//
// RESULTADO (2026-10-13): sem HIGH/CRITICAL. O que o delta escreveu RESISTIU — o fuzz do bloc (600 sequências, ~890 falhas de carga, ~280
// sob operação longa, 58 "Tentar novamente") não achou `loadFailed` fora da falha da carga nem "lista vazia" nascida de falha; a matriz de
// rede (50 combinações) não vazou URL/exceção/token; o 401 (D-F148), o desconhecido do ato (D-F139) e a linha do lote (D-F176/D-F180) não
// mudaram; o caso do passeio do P-04 sai certo. Achados LOW: PSO-ADV-01 (o "Tentar novamente" volta à página 1), PSO-ADV-02 (a recarga
// do fim do lote que falha apaga a seleção das recusadas), PSO-ADV-03 (o core chama de "rede" a resposta ilegível, sem código),
// PSO-ADV-05 (200 sem envelope = "nenhum registro"), PSO-ADV-08 (o P-04 repete a mensagem do campo contida na principal) e PSO-ADV-09
// (anterior ao delta — o `finally` do handler anterior baixa a trava de reentrância da operação seguinte; achado pelo oráculo do
// `loading` do fuzz). FATOs: PSO-ADV-04 (`developer.log` é no-op no build de produção), PSO-ADV-06 (falhas de rede iguais → a D-F198
// colapsa desfechos de atos diferentes), PSO-ADV-07 (o código curto não chega aos avisos do ato fiscal).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_nfse_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_nfse_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/page/service_order_page.dart';
import 'package:setes_web/app/shared/search/search_criteria_datasource.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

import 'support/service_order_bloc_factory.dart';

const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';
const _blocSrc = 'lib/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
const _coreClientSrc = '../../packages/core/lib/src/shared/http/api_client.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

const _newId = 77;
const _aId = 7374;
const _newOrder = ServiceOrderFull(id: _newId, number: 8001, customerId: 5);
const _a = ServiceOrderFull(id: _aId, number: 77, customerId: 1, status: 'F');
const _aVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
const _aEffect = ServiceOrderFiscalEffect();
const _authorizedBlocks = [
  CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
];

/// A falha de rede como o `ApiClient` a monta HOJE (D-F205) — a mesma para todo pedido ao MESMO serviço.
final _erpDown = NetworkFailure(detail: networkFailureCode('setes-api'));
final _nfseDownRepo = NetworkFailure(message: 'forms.serviceOrder.fiscalNoResponse', detail: networkFailureCode('nfse-api'));

/// O que o navegador entrega ao `http` quando o proxy responde 502/504 SEM CORS (provado no passeio) — com a URL interna.
http.ClientException _failedToFetch(String url) => http.ClientException('Failed to fetch', Uri.parse(url));

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

PagedResult<ServiceOrderListItem> _listPage(List<int> ids, {int page = 1, int pageSize = 10, int? total}) => PagedResult(items: [
      for (final id in ids) ServiceOrderListItem(id: id, number: 7000 + id, customerId: id, customerName: 'Cliente $id', status: 'A'),
    ], page: page, pageSize: pageSize, total: total ?? ids.length);

String _envelope(List<int> ids, {int page = 1, int pageSize = 10, int? total}) => jsonEncode({
      'ok': true,
      'data': [for (final id in ids) {'id': id, 'number': 7000 + id, 'customerId': id, 'customerName': 'Cliente $id', 'status': 'A'}],
      'page': page,
      'pageSize': pageSize,
      'total': total ?? ids.length,
    });

class _OsDsMock extends Mock implements ServiceOrderDatasource {}

class _SearchDsMock extends Mock implements SearchCriteriaDatasource {}

/// Os binds que a `ServiceOrderPage` pede (`Modular.get` no initState) — a página REAL sobre o bloc do teste.
class _PageModule extends Module {
  _PageModule(this.bloc, this.ds, this.search);
  final ServiceOrderBloc bloc;
  final ServiceOrderDatasource ds;
  final SearchCriteriaDatasource search;

  @override
  List<Bind> get binds => [
        Bind.instance<ServiceOrderBloc>(bloc),
        Bind.instance<ServiceOrderDatasource>(ds),
        Bind.instance<SearchCriteriaDatasource>(search),
      ];
}

/// Monta a página de OS de verdade sobre [bloc] e devolve o desmontador (página → bloc → Modular).
Future<Future<void> Function()> _pumpPage(WidgetTester tester, ServiceOrderBloc bloc, {ServiceOrderDatasource? ds}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  final search = _SearchDsMock();
  when(() => search.criteria()).thenAnswer((_) async => const <SearchCriterion>[]);
  Modular.init(_PageModule(bloc, ds ?? _OsDsMock(), search));
  var destroyed = false;
  void destroy() {
    if (destroyed) return;
    destroyed = true;
    try {
      Modular.destroy();
    } catch (_) {}
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  addTearDown(destroy);   // teste que falha no meio não deixa o Modular montado para o próximo
  await tester.pumpWidget(const MaterialApp(home: ServiceOrderPage(title: 'Ordens de Serviço')));
  await _settle(tester);
  return () async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(bloc.close);   // o close do bloc não termina dentro do FakeAsync do testWidgets
    destroy();
  };
}

/// O spinner da lista anima para sempre — nada de `pumpAndSettle` com a lista em loading.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// O texto da caixa de diálogo aberta (o `SetesText(message)` do `showSetesMessage`).
List<String> _dialogTexts(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '',
    ];

// -------------------------------------------------------------------------------------------------------------------------------------
// Fuzz do bloc (D-F206): respostas ESTACIONADAS, concluídas em ordem aleatória, com falhas aleatórias.
// -------------------------------------------------------------------------------------------------------------------------------------

class _ListArgs {
  const _ListArgs(this.status, this.filter, this.page, this.pageSize, this.criteria);
  final String status;
  final String filter;
  final int page;
  final int? pageSize;
  final String criteria;

  bool get hasK => (jsonDecode(criteria) as Map).containsKey('k');

  @override
  String toString() => '$status|"$filter"|p$page|s$pageSize|$criteria';
}

class _Flight {
  _Flight(this.kind, this.finish, {this.args});
  final String kind;
  final void Function(Failure? failure) finish;
  final _ListArgs? args;
}

/// As operações LONGAS (o `_batchInFlight` do bloc): o loading da lista tem de durar o que elas duram (D-F169/D-F179).
const _longKinds = {'monthly', 'batch', 'pending', 'ftransmit'};

/// A recusa de critério (Q-BA16 a) — com o critério 'k' aplicado ela é PODADA (não é falha da carga); sem ele é falha comum.
const _criterionRefused =
    Failure(message: 'critério recusado', statusCode: 422, code: 'SEARCH_CRITERION_INVALID', fields: [FailureField(field: 'k', message: 'valor inválido')]);

class _FuzzResult {
  final violations = <String>[];
  final counts = <String, int>{};
  void count(String k) => counts[k] = (counts[k] ?? 0) + 1;
}

Future<void> _fuzz(int seed, _FuzzResult out, {int steps = 40}) async {
  final rnd = Random(seed);
  final flights = <_Flight>[];
  final listCalls = <_ListArgs>[];
  Future<Either<Failure, T>> park<T>(String kind, T Function() ok, {_ListArgs? args}) {
    final c = Completer<Either<Failure, T>>();
    flights.add(_Flight(kind, (f) => c.complete(f == null ? Right(ok()) : Left(f)), args: args));
    return c.future;
  }

  final repo = ServiceOrderRepoMock();
  final nfse = NfseRepoMock();
  final invoice = InvoiceRepoMock();
  when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
      .thenAnswer((inv) {
    final args = _ListArgs(inv.positionalArguments[0] as String, inv.positionalArguments[1] as String, inv.namedArguments[#page] as int,
        inv.namedArguments[#pageSize] as int?, (inv.namedArguments[#criteria] as SearchCriteriaValues).toQueryJson());
    listCalls.add(args);
    return park('list', () => _listPage([_newId, _aId], page: args.page, pageSize: args.pageSize ?? 10, total: 30), args: args);
  });
  when(() => repo.getById(_newId)).thenAnswer((_) => park('get', () => _newOrder));
  when(() => repo.getById(_aId)).thenAnswer((_) => park('get', () => _a));
  when(() => nfse.getView(_aId)).thenAnswer((_) => park('voice', () => _aVoice));
  when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) => park('effect', () => _aEffect));
  when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
  when(() => repo.batchInvoice(any(), any()))
      .thenAnswer((_) => park('batch', () => BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: _newId, ok: true)])));
  when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => park('pending',
      () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: '9001')], page: 1, pageSize: 100, total: 1)));
  when(() => nfse.transmit(any())).thenAnswer((_) => park('ftransmit', () => const ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1)));
  when(() => repo.invoice(_newId, any())).thenAnswer((_) => park('act', () => const ServiceOrderInvoiceResult(invoiceNumber: '1')));
  when(() => repo.cancel(_newId)).thenAnswer((_) => park('act', () => unit));
  when(() => repo.itemPost(_newId, any())).thenAnswer((_) => park('act', () => 1));

  final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
  final states = <ServiceOrderState>[];
  final stepEmits = <ServiceOrderState>[];
  final sub = bloc.stream.listen((s) {
    states.add(s);
    stepEmits.add(s);
  });
  ServiceOrderState? shown() => states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
  // a falha de carga que pôs o `loadFailed` mostrado na tela (o "Tentar novamente" tem de refazer ESTE pedido)
  final failedArgsOf = <ServiceOrderListState, _ListArgs>{};
  bool longParked() => flights.any((f) => _longKinds.contains(f.kind));
  String why(int step, String what) => 'semente $seed passo $step: $what';

  Failure listFailure() => switch (rnd.nextInt(4)) {
        0 => _erpDown,
        1 => const Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'R-500'),
        2 => const Failure(message: 'Sem privilégio', statusCode: 403, code: 'FORBIDDEN'),
        _ => _criterionRefused,
      };
  Failure otherFailure() => rnd.nextBool() ? _erpDown : const Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL');

  ServiceOrderEvent? pick() {
    switch (rnd.nextInt(13)) {
      case 0:
      case 1:
      case 2:
        // aba, filtro, página, tamanho, critérios (o que a página manda: troca de aba, pesquisa, barra, chips/painel)
        return ServiceOrderListRequested(
          status: const [null, 'A', 'F'][rnd.nextInt(3)],
          filter: const [null, '', 'x'][rnd.nextInt(3)],
          page: 1 + rnd.nextInt(3),
          pageSize: const [null, 10, 25][rnd.nextInt(3)],
          criteria: const [null, SearchCriteriaValues.empty, SearchCriteriaValues({'k': 'v'}), SearchCriteriaValues({'j': 'w'})][rnd.nextInt(4)],
        );
      case 3:
        return ServiceOrderViewRequested(rnd.nextBool() ? _newId : _aId);
      case 4:
        return const ServiceOrderBackToListPressed();
      case 5:
        return const ServiceOrderMonthlyRunRequested(year: 2026, month: 10);
      case 6:
        return const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input);
      case 7:
        return const ServiceOrderFiscalPendingRequested();
      case 8:
        return const ServiceOrderFiscalTransmitBatchRequested([_aId]);
      case 9:
        return const ServiceOrderInvoiceRequested(orderId: _newId, input: _input);
      case 10:
        return const ServiceOrderCancelRequested(_newId);
      case 11:
        return const ServiceOrderItemSaveRequested(orderId: _newId, input: _item);
      default:
        // o "Tentar novamente" da PÁGINA — o botão só existe com `loadFailed && !loading`, e manda exatamente isto
        final s = shown();
        if (s is ServiceOrderListState && s.loadFailed && !s.loading) {
          return ServiceOrderListRequested(status: s.status, filter: s.filter, page: s.page);
        }
        return null;
    }
  }

  final trail = <String>[];   // os últimos passos (diagnóstico de violação)
  // MODELO do PSO-ADV-09: o handler de uma operação longa baixa a marca ANTES da recarga final (D-F169) e de novo no `finally` — que
  // só roda quando a recarga final VOLTA. [finallyOf]: tipo → a recarga final do handler anterior ainda no ar; [cleared]: tipos cuja
  // operação CORRENTE teve a marca baixada pelo `finally` do handler anterior (o `_batchInFlight` mente enquanto ela roda).
  final finallyOf = <String, List<_Flight>>{};
  final cleared = <String>{};
  bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));   // o initState da página
  await pumpEventQueue(times: 20);
  for (var step = 0; step < steps + 300; step++) {
    final draining = step >= steps;
    if (draining && flights.isEmpty) break;
    stepEmits.clear();
    final before = bloc.state;
    _Flight? done;
    Failure? failure;
    _ListArgs? retryOf;
    var callsBefore = listCalls.length;
    final flightsBefore = flights.toSet();
    if (flights.isNotEmpty && (draining || rnd.nextInt(10) < 5)) {
      done = flights.removeAt(rnd.nextInt(flights.length));
      failure = !draining && rnd.nextInt(3) == 0 ? (done.kind == 'list' ? listFailure() : otherFailure()) : null;
      done.finish(failure);
      trail.add('fim ${done.kind}${failure == null ? '' : ' FALHA ${failure.runtimeType}${failure.code ?? ''}'}');
    } else {
      final e = pick();
      if (e == null) continue;
      final s = shown();
      if (e is ServiceOrderListRequested && s is ServiceOrderListState && s.loadFailed && !s.loading && e.status == s.status &&
          e.filter == s.filter && e.page == s.page && e.criteria == null && e.pageSize == null) {
        retryOf = failedArgsOf[s];
      }
      callsBefore = listCalls.length;
      trail.add(e.runtimeType.toString().replaceAll('ServiceOrder', '').replaceAll('Requested', ''));
      bloc.add(e);
    }
    await pumpEventQueue(times: 20);
    final newFlights = flights.where((f) => !flightsBefore.contains(f)).toList();
    final newLists = newFlights.where((f) => f.kind == 'list').toList();
    // uma operação longa COMEÇOU (a guarda deixou): a marca sobe — vale para todas as do tipo
    for (final f in newFlights.where((f) => _longKinds.contains(f.kind) && done == null)) {
      cleared.remove(f.kind);
    }
    if (done != null && _longKinds.contains(done.kind)) {
      // o handler baixa a marca ANTES da recarga final: se outra do MESMO tipo segue no ar, ela fica sem marca
      if (flights.any((f) => f.kind == done!.kind)) {
        cleared.add(done.kind);
      } else {
        cleared.remove(done.kind);
      }
      if (newLists.isNotEmpty) (finallyOf[done.kind] ??= []).add(newLists.last);   // o `finally` espera ESTA recarga
    }
    if (done != null && done.kind == 'list') {
      for (final k in finallyOf.keys.toList()) {
        final waiting = finallyOf[k]!;
        if (!waiting.any((f) => identical(f, done))) continue;
        waiting.removeWhere((f) => identical(f, done));
        if (newLists.isNotEmpty) {
          waiting.add(newLists.last);   // a recarga recursiva (critério podado) — o `finally` segue esperando
        } else if (flights.any((f) => f.kind == k)) {
          cleared.add(k);   // o `finally` de um handler ANTERIOR acaba de baixar a marca da operação que roda AGORA
          out.count('PSO-ADV-09 finally antigo baixou a marca de $k em voo');
        }
      }
    }
    bool loadingOk(bool loading) {
      if (loading == longParked()) return true;
      final live = flights.where((f) => _longKinds.contains(f.kind)).map((f) => f.kind).toSet();
      if (!loading && live.every(cleared.contains)) {
        out.count('PSO-ADV-09 lista LIVRE com operação longa no ar');
        return true;
      }
      return false;
    }

    final listFail = done?.kind == 'list' && failure != null;
    final pruned = listFail && isSearchCriteriaFailure(failure) && done!.args!.hasK;
    if (listFail && !pruned) {
      final args = done!.args!;
      if (stepEmits.isEmpty) {
        out.count('falha de carga SUPERADA (não emite)');
      } else {
        final full = stepEmits.length == 2 && stepEmits[0] == ServiceOrderActionFailure(failure);
        final dedup = stepEmits.length == 1 && before == ServiceOrderActionFailure(failure);
        final st = stepEmits.last;
        if (!(full || dedup) || st is! ServiceOrderListState) {
          out.violations.add(why(step, '(A) falha da carga $args emitiu $stepEmits'));
        } else {
          if (dedup) out.count('falha de carga com o diálogo igual ao anterior (D-F198)');
          if (!st.loadFailed) out.violations.add(why(step, '(A) falha da carga sem loadFailed: $st'));
          if (st.items.isNotEmpty) out.violations.add(why(step, '(A) loadFailed com itens'));
          if (st.status != args.status || st.filter != args.filter || st.criteria.toQueryJson() != args.criteria) {
            out.violations.add(why(step, '(A) loadFailed ≠ pedido que falhou: ${st.status}|${st.filter}|${st.criteria.toQueryJson()} × $args'));
          }
          if (!loadingOk(st.loading)) {
            out.violations.add(why(step, '(A) loadFailed com loading ${st.loading} e operação longa no ar = ${longParked()} (D-F169) — no ar: '
                '${flights.map((f) => f.kind).toList()}; trilha: ${trail.skip(max(0, trail.length - 12)).join(' > ')}'));
          }
          if (st.loading) out.count('loadFailed sob operação longa (loading: true)');
          out.count('loadFailed emitido');
          if (st.page != args.page) out.count('PSO-ADV-01 loadFailed com page ${st.page} ≠ pedido ${args.page}');
          failedArgsOf[st] = args;
        }
      }
    } else {
      for (final s in stepEmits.whereType<ServiceOrderListState>()) {
        if (s.loadFailed) {
          out.violations.add(why(step, '(B) loadFailed fora da falha da carga (${done?.kind ?? 'evento'} ${failure ?? ''}): $s'));
        }
      }
      if (pruned && stepEmits.isNotEmpty) out.count('recusa de critério PODADA (sem loadFailed)');
    }
    if (done?.kind == 'list' && failure == null) {
      // D-F169 também na lista CARREGADA: com operação longa no ar ela sai em loading
      for (final s in stepEmits.whereType<ServiceOrderListState>().where((s) => s.items.isNotEmpty)) {
        if (!loadingOk(s.loading)) {
          out.violations.add(why(step, '(E) lista carregada com loading ${s.loading} e operação longa no ar = ${longParked()} — no ar: '
              '${flights.map((f) => f.kind).toList()}; trilha: ${trail.skip(max(0, trail.length - 12)).join(' > ')}'));
        }
      }
    }
    for (final s in stepEmits.whereType<ServiceOrderListState>()) {
      if (!s.loading && !s.loadFailed && s.items.isEmpty) out.violations.add(why(step, '(C) "nenhum registro" emitido: $s'));
      if (!s.loadFailed) out.count('lista sem falha emitida (loadFailed: false)');
    }
    if (retryOf != null) {
      out.count('Tentar novamente');
      final next = listCalls.length > callsBefore ? listCalls[callsBefore] : null;
      if (next == null) {
        out.violations.add(why(step, '(D) "Tentar novamente" não pediu a lista'));
      } else {
        if (next.status != retryOf.status || next.filter != retryOf.filter || next.pageSize != retryOf.pageSize ||
            next.criteria != retryOf.criteria) {
          out.violations.add(why(step, '(D) "Tentar novamente" pediu $next ≠ o pedido que falhou $retryOf'));
        }
        if (next.criteria != '{}') out.count('Tentar novamente MANTEVE critérios');
        if (next.page != retryOf.page) out.count('PSO-ADV-01 Tentar novamente pediu a página ${next.page} ≠ ${retryOf.page}');
      }
    }
  }
  if (flights.isNotEmpty) out.violations.add('semente $seed: ${flights.length} respostas nunca concluídas');
  await sub.cancel();
  await bloc.close();
}

/// As PROVAS de antes das correções da sessão (gates do passeio, 2026-10-13 — "siga as recomendações"): o comportamento que cada FATO
/// registrava não existe mais; ficam PULADAS como histórico (a convenção das provas superadas do R9) — o [CORRIGIDO] de cada achado prova
/// o novo. Para revê-las: `flutter test --run-skipped test/adversarial_passeio_gate_test.dart` (elas FALHAM — é o esperado).
const _supersededReason = 'prova de ANTES da correção da sessão (gates do passeio) — o [CORRIGIDO] do achado prova o comportamento novo';
void _superseded(String name, dynamic Function() body, {Timeout? timeout, Object? skip}) =>   // [skip] do teste original: sempre pulado
    test('[SUPERADO] $name', body, skip: _supersededReason, timeout: timeout);
void _supersededWidgets(String name, WidgetTesterCallback body, {Timeout? timeout}) =>
    testWidgets('[SUPERADO] $name', body, skip: true, timeout: timeout);   // _supersededReason

void main() {
  final pt = _load('pt');
  final en = _load('en');

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  // ---------------------------------------------------------------------
  // 1. D-F206 — o estado de falha da carga no bloc (fuzz + sequências dirigidas)
  // ---------------------------------------------------------------------
  group('D-F206 × fuzz do bloc — falha da carga, lote por cima, fim de lote, rotina mensal, pendentes, aba/filtro/página/critérios, detalhe, faturar/cancelar', () {
    test('[RESISTIU] 600 sequências (40 passos + dreno): a falha da carga sai SEMPRE como [ActionFailure, ListState(loadFailed)] (ou é superada), sem itens, com aba/filtro/critérios do pedido que falhou e o `loading` = operação longa no ar (D-F169 — também na lista CARREGADA; a ÚNICA exceção medida é a do PSO-ADV-09, modelada: a marca baixada pelo `finally` de um handler anterior); NENHUMA outra emissão de lista leva `loadFailed`; nenhuma "lista vazia" nasce de falha; o "Tentar novamente" refaz aba/filtro/tamanho/critérios',
        () async {
      final out = _FuzzResult();
      final seeds = int.tryParse(Platform.environment['PSO_SEEDS'] ?? '') ?? 600;
      for (var seed = 1; seed <= seeds; seed++) {
        await _fuzz(seed, out);
      }
      // ignore: avoid_print
      print('fuzz D-F206: ${out.counts}');
      expect(out.violations.take(10).toList(), isEmpty);
      // o fuzz passou pelos caminhos que importam
      for (final k in ['loadFailed emitido', 'loadFailed sob operação longa (loading: true)', 'Tentar novamente', 'Tentar novamente MANTEVE critérios',
        'recusa de critério PODADA (sem loadFailed)', 'falha de carga SUPERADA (não emite)']) {
        expect(out.counts[k] ?? 0, greaterThan(0), reason: k);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));   // ~20 s sozinho; a suíte inteira roda os arquivos em paralelo

    _superseded('[FATO PSO-ADV-01] o estado de falha NÃO leva a página do pedido que falhou (nem o pageSize): ele nasce com `page: 1` (default) e o "Tentar novamente" da página manda `page: state.page` — volta à página 1. Contado no fuzz e provado aqui: página 3 que falha → retry pede a página 1',
        () async {
      final repo = ServiceOrderRepoMock();
      final pages = <int>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        final page = inv.namedArguments[#page] as int;
        pages.add(page);
        return pages.length == 2 ? Left(_erpDown) : Right(_listPage([1, 2], page: page, total: 30));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(page: 3));   // a barra de paginação (onPageChanged)
      await pumpEventQueue(times: 20);
      final failed = states.whereType<ServiceOrderListState>().last;
      bloc.add(ServiceOrderListRequested(status: failed.status, filter: failed.filter, page: failed.page));   // o botão da página
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([failed.loadFailed, failed.page, failed.pageSize, failed.total], [true, 1, null, null]);
      expect(pages, [1, 3, 1]);
      expect(File(_pageSrc).readAsStringSync(),
          contains('_dispatch(ServiceOrderListRequested(status: state.status, filter: state.filter, page: state.page))'));
      expect(File(_blocSrc).readAsStringSync(),
          contains('loading: _batchInFlight, status: _status, filter: _filter, criteria: _criteria, loadFailed: true));'));
    });

    test('[CORRIGIDO D-F206/PSO-ADV-01 — a falha guarda página e tamanho — era o ACHADO PSO-ADV-01 LOW] o "Tentar novamente" refaz o MESMO pedido — a página que falhou (o estado de falha leva `page: _page, pageSize: _pageSize`)',
        () async {
      final repo = ServiceOrderRepoMock();
      final pages = <int>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        final page = inv.namedArguments[#page] as int;
        pages.add(page);
        return pages.length == 2 ? Left(_erpDown) : Right(_listPage([1, 2], page: page, total: 30));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(page: 3));
      await pumpEventQueue(times: 20);
      final failed = states.whereType<ServiceOrderListState>().last;
      bloc.add(ServiceOrderListRequested(status: failed.status, filter: failed.filter, page: failed.page));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(pages, [1, 3, 3]);
    });

    test('[RESISTIU] a falha da carga com o lote no ar (D-F169): `loading: true` + `loadFailed: true` (a página mostra o spinner, nunca o botão); o FIM do lote recarrega e a lista volta com `loadFailed: false`',
        () async {
      final repo = ServiceOrderRepoMock();
      final batch = Completer<Either<Failure, BatchInvoiceReport>>();
      var calls = 0;
      final list = <Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        calls++;
        final c = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
        list.add(c);
        return c.future;
      });
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => batch.future);
      final bloc = buildServiceOrderBloc(repo: repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1], input: _input));   // o lote NÃO supera a carga em voo (supersede: false)
      await pumpEventQueue(times: 20);
      list.first.complete(Left(_erpDown));
      await pumpEventQueue(times: 20);
      final underBatch = states.whereType<ServiceOrderListState>().last;
      batch.complete(Right(BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: 1, ok: true)])));
      await pumpEventQueue(times: 20);
      list.last.complete(Right(_listPage([2])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final end = states.whereType<ServiceOrderListState>().last;
      expect([underBatch.loading, underBatch.loadFailed], [true, true]);
      expect([calls, end.loading, end.loadFailed, end.items.length], [2, false, false, 1]);
    });

    /// PSO-ADV-09: lote fiscal 1 termina com a recarga final LENTA (o proxy segurando o pedido — o cenário do passeio); o operador troca
    /// de aba (a lista nova volta livre — certo, o lote 1 acabou), tira as pendentes e confirma o lote 2; a recarga velha enfim volta
    /// (504) e o `finally` do handler do lote 1 baixa `_fiscalBatchRunning` — a do lote 2. Devolve (lista pedida no meio do lote 2,
    /// transmissões da MESMA nota no ar).
    Future<(ServiceOrderListState, int)> fiscalBatchDuringOldFinally() async {
      final repo = ServiceOrderRepoMock();
      final nfse = NfseRepoMock();
      final lists = <Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>>[];
      final transmits = <Completer<Either<Failure, ServiceOrderTransmitResult>>>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        final c = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
        lists.add(c);
        return c.future;
      });
      when(() => nfse.transmit(_aId)).thenAnswer((_) {
        final c = Completer<Either<Failure, ServiceOrderTransmitResult>>();
        transmits.add(c);
        return c.future;
      });
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) async =>
          const Right(PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: '9001')], page: 1, pageSize: 100, total: 1)));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      Future<void> step(void Function() act) async {
        act();
        await pumpEventQueue(times: 20);
      }

      final ok = Right<Failure, PagedResult<ServiceOrderListItem>>(_listPage([_aId]));
      await step(() => bloc.add(const ServiceOrderListRequested(status: 'F', filter: '')));
      await step(() => lists.last.complete(ok));
      await step(() => bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_aId])));   // lote 1
      await step(() => transmits.last.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1))));
      final slowFinalReload = lists.last;                                                     // a recarga final do lote 1 — presa no proxy
      await step(() => bloc.add(const ServiceOrderListRequested(status: 'A')));              // troca de aba (a TabBar segue ativa)
      await step(() => lists.last.complete(ok));
      await step(() => bloc.add(const ServiceOrderListRequested(status: 'F')));
      await step(() => lists.last.complete(ok));
      await step(() => bloc.add(const ServiceOrderFiscalPendingRequested()));                // "Transmitir pendentes"
      await step(() => lists.last.complete(ok));
      await step(() => bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_aId])));   // confirmou: lote 2 no ar
      await step(() => slowFinalReload.complete(Left(_erpDown)));                             // a recarga velha volta (superada)
      await step(() => bloc.add(const ServiceOrderListRequested(status: 'A')));              // troca de aba NO MEIO do lote 2
      await step(() => lists.last.complete(ok));
      final during = states.whereType<ServiceOrderListState>().last;
      await step(() => bloc.add(const ServiceOrderListRequested(status: 'F')));
      await step(() => lists.last.complete(ok));
      await step(() => bloc.add(const ServiceOrderFiscalPendingRequested()));                // o botão reabriu: de novo
      // com a trava COM DONO (correção do PSO-ADV-09) a fotografia NÃO passa da guarda com o lote 2 no ar — nenhuma recarga a completar
      await step(() {
        if (!lists.last.isCompleted) lists.last.complete(ok);
      });
      await step(() => bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_aId])));   // lote 3 — junto com o 2
      final inFlight = transmits.where((c) => !c.isCompleted).length;
      for (final c in transmits.where((c) => !c.isCompleted)) {
        c.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1)));
      }
      await pumpEventQueue(times: 20);
      for (final c in lists.where((c) => !c.isCompleted)) {
        c.complete(ok);
      }
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      return (during, inFlight);
    }

    _superseded('[FATO PSO-ADV-09] a trava de reentrância da D-F179 é baixada pelo `finally` do handler ANTERIOR: cada operação longa baixa a marca antes da recarga final (D-F169) e DE NOVO no `finally`, que só roda quando essa recarga VOLTA — se ela volta depois de a operação SEGUINTE começar, a marca da seguinte cai. Com o lote fiscal 2 no ar, a lista pedida na troca de aba sai LIVRE (`loading: false` — a trava H1 reabre, e com a D-F206 o "Tentar novamente" também) e o "Transmitir pendentes" seguinte passa pela guarda: DUAS transmissões da MESMA nota no ar (o servidor barra pela trava da nota — D-F183 —, a linha vira "incerta"). O mesmo padrão nos 4 handlers (rotina mensal, pendentes, lote fiscal, lote de faturamento)',
        () async {
      final (during, inFlight) = await fiscalBatchDuringOldFinally();
      expect([during.loading, during.loadFailed], [false, false]);
      expect(inFlight, 2);
      final src = File(_blocSrc).readAsStringSync();
      for (final flag in ['_monthlyRunning', '_batchRunning', '_fiscalPendingRunning', '_fiscalBatchRunning']) {
        expect(RegExp('finally \\{\\s*$flag = false;').hasMatch(src), isTrue, reason: flag);
        expect(RegExp('$flag = false;   // D-F169').hasMatch(src), isTrue, reason: flag);
      }
    });

    test('[CORRIGIDO trava COM DONO (_RunLock) — era o ACHADO PSO-ADV-09 LOW] o fim de uma operação longa nunca baixa a marca de OUTRA que começou depois: com o lote fiscal 2 no ar a lista sai em loading e o 3º lote não vai ao fisco',
        () async {
      final (during, inFlight) = await fiscalBatchDuringOldFinally();
      expect([during.loading, inFlight], [true, 1]);
    });

    _superseded('[FATO PSO-ADV-05] a lista de OS que volta 200 SEM o envelope (página HTML do proxy/host trocado — o `ApiClient` do setes-api é tolerante, `strictEnvelope: false`) vira "lista vazia": `PagedResult.fromJson({})` dá 0 itens e a tela diz "Não encontramos nenhum registro" — a D-F206 ("a falha não é uma lista vazia") não cobre a resposta ilegível. O `envelopePage` do core (D-F130) existe para isto e o datasource da OS não o usa',
        () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html><body>Plesk - site em manutencao</body></html>', 200)),
          baseUrl: 'https://api.setes.example');
      final repo = ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api));
      final bloc = buildServiceOrderBloc(repo: repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 30);
      await sub.cancel();
      await bloc.close();
      final last = states.whereType<ServiceOrderListState>().last;
      expect([last.loading, last.loadFailed, last.items.isEmpty, states.whereType<ServiceOrderActionFailure>().length], [false, false, true, 0]);
      expect(File('lib/app/modules/service_orders/data/datasource/service_order_datasource.dart').readAsStringSync(),
          contains('return PagedResult.fromJson(json, ServiceOrderListItem.fromJson);'));
    });

    test('[CORRIGIDO envelopePage na lista de OS — era o ACHADO PSO-ADV-05 LOW] a lista de OS com 200 que não é o envelope paginado é FALHA da carga (`CLIENT_INVALID_RESPONSE` → loadFailed), nunca "nenhum registro"',
        () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html>proxy</html>', 200)), baseUrl: 'https://api.setes.example');
      final repo = ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api));
      final bloc = buildServiceOrderBloc(repo: repo);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 30);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderListState>().last.loadFailed, isTrue);
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code, ClientFailureCodes.invalidResponse);
    });
  });

  // ---------------------------------------------------------------------
  // 2. D-F206 na PÁGINA de verdade (o botão, o texto, a seleção do lote)
  // ---------------------------------------------------------------------
  group('D-F206 × a página de OS montada', () {
    testWidgets('[RESISTIU] ponta a ponta sem servidor (ApiClient REAL → datasource → repositório → bloc → página): o proxy sem CORS ("Failed to fetch" com a URL interna) mostra a frase NEUTRA (D-F204) + "Informe o código NETWORK · setes-api ao suporte" (D-F205), nenhum texto com URL/exceção; o corpo diz "Não foi possível carregar a lista." + "Tentar novamente" (nunca "nenhum registro"); o botão recarrega e a lista volta',
        (tester) async {
      var n = 0;
      final urls = <String>[];
      final api = ApiClient(
        client: MockClient((req) async {
          urls.add(req.url.toString());
          if (++n == 1) throw _failedToFetch('https://api.interna.setes.example:3000/api/service-orders?status=A&page=1');
          return http.Response(_envelope([1, 2]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        baseUrl: 'https://api.interna.setes.example:3000',
      );
      final ds = ServiceOrderDatasourceImpl(client: api);
      final bloc = buildServiceOrderBloc(repo: ServiceOrderRepositoryImpl(datasource: ds));
      final dispose = await _pumpPage(tester, bloc, ds: ds);
      final dialog = _dialogTexts(tester);
      expect(dialog, containsAll(['Erro', 'Sem resposta do serviço — rede, proxy ou tempo.', 'Informe o código NETWORK · setes-api ao suporte']));
      final everything = [
        for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? '',
      ].join('\n');
      for (final leak in ['http', 'interna', 'Failed to fetch', 'ClientException', '3000']) {
        expect(everything, isNot(contains(leak)), reason: leak);
      }
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect([find.text('Não foi possível carregar a lista.').evaluate().length, find.text('Tentar novamente').evaluate().length,
        find.text('Não encontramos nenhum registro em nossa base.').evaluate().length], [1, 1, 0]);
      await tester.tap(find.text('Tentar novamente'));
      await _settle(tester);
      expect([find.text('Cliente 1').evaluate().length, find.text('Não foi possível carregar a lista.').evaluate().length], [1, 0]);
      expect(urls.length, 2);
      await dispose();
    });

    _supersededWidgets('[FATO PSO-ADV-01] pela página: a barra pede a página 3, a carga falha, "Tentar novamente" pede a página 1', (tester) async {
      final repo = ServiceOrderRepoMock();
      final pages = <int>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        final page = inv.namedArguments[#page] as int;
        pages.add(page);
        return pages.length == 2 ? Left(_erpDown) : Right(_listPage([1, 2], page: page, total: 30));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      bloc.add(const ServiceOrderListRequested(page: 3));   // = RegisterPagingBar.onPageChanged
      await _settle(tester);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      await tester.tap(find.text('Tentar novamente'));
      await _settle(tester);
      expect(pages, [1, 3, 1]);
      await dispose();
    });

    _supersededWidgets('[FATO PSO-ADV-02] a seleção do lote MORRE quando a recarga do FIM do lote falha: o estado de falha entra na assinatura da seleção (`if (!state.loading)` — page 1/pageSize null ≠ a lista carregada) e `_selected.clear()`; o relatório fecha, "Tentar novamente" traz a MESMA lista e a recusada não está mais marcada — a promessa "as recusadas CONTINUAM marcadas, para o operador corrigir e repetir só elas" quebra',
        (tester) async {
      final repo = ServiceOrderRepoMock();
      var n = 0;
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => ++n == 2 ? Left(_erpDown) : Right(_listPage(n == 1 ? [1, 2] : [1])));
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async => Right(BatchInvoiceReport.fromEntries(const [
            BatchInvoiceEntry(orderId: 1, ok: false, error: 'sem forma de pagamento'),
            BatchInvoiceEntry(orderId: 2, ok: true, invoiceNumber: '501'),
          ])));
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await _settle(tester);
      expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value), [true, true]);
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));   // o que `_invoiceSelected` despacha
      await _settle(tester);
      await tester.tap(find.text('OK'));                 // o erro da recarga (por cima do relatório)
      await _settle(tester);
      await tester.tap(find.text('Fechar'));             // o relatório do lote: só a recusada (OS 1) deveria seguir marcada
      await _settle(tester);
      await tester.tap(find.text('Tentar novamente'));
      await _settle(tester);
      expect(n, 3);
      expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value), [false]);
      expect(File(_pageSrc).readAsStringSync(), contains('if (!state.loading) {'));
      await dispose();
    });

    testWidgets('[CORRIGIDO a seleção ignora o estado de falha — era o ACHADO PSO-ADV-02 LOW] a recarga do fim do lote que FALHA não apaga a seleção das recusadas: depois do "Tentar novamente" a OS recusada segue marcada',
        (tester) async {
      final repo = ServiceOrderRepoMock();
      var n = 0;
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => ++n == 2 ? Left(_erpDown) : Right(_listPage(n == 1 ? [1, 2] : [1])));
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async => Right(BatchInvoiceReport.fromEntries(const [
            BatchInvoiceEntry(orderId: 1, ok: false, error: 'sem forma de pagamento'),
            BatchInvoiceEntry(orderId: 2, ok: true, invoiceNumber: '501'),
          ])));
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await _settle(tester);
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));
      await _settle(tester);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      await tester.tap(find.text('Fechar'));
      await _settle(tester);
      await tester.tap(find.text('Tentar novamente'));
      await _settle(tester);
      expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value), [true]);
      await dispose();
    });
  });

  // ---------------------------------------------------------------------
  // 3. D-F205 — o código curto em TODA porta de rede do ApiClient/NfseApiClient
  // ---------------------------------------------------------------------
  group('D-F205 × as portas de rede do ProductApiClient', () {
    final throwers = <String, Object Function()>{
      'ClientException do navegador (proxy sem CORS)': () => _failedToFetch('https://api.interna.setes.example/api/x?token=abc'),
      'XMLHttpRequest error (http antigo)': () => http.ClientException('XMLHttpRequest error.', Uri.parse('https://nfse.interna.setes.example/v1/x')),
      'SocketException (Android/desktop)': () => const SocketException('Connection refused', osError: OSError('Connection refused', 111), port: 3000),
      'TimeoutException': () => TimeoutException('sem resposta de https://api.interna.setes.example', const Duration(seconds: 30)),
      'StateError (cliente fechado)': () => StateError('Client is already closed. https://api.interna.setes.example'),
    };
    test('[RESISTIU] 2 clientes × 5 portas (get/post/put/delete/post com token de seleção) × 5 exceções: SEMPRE `NetworkFailure`, mensagem `core.errors.network`, `supportRef` = `NETWORK · setes-api|nfse-api`, sem código/status/fields; nada de URL, host, porta, exceção ou token na mensagem, no ref ou no toString',
        () async {
      var checked = 0;
      for (final MapEntry(key: label, value: boom) in throwers.entries) {
        final client = MockClient((_) async => throw boom());
        final token = ProductToken()..value = 'jwt.da.sessao';
        final clients = <(ProductApiClient, String)>[
          (ApiClient(client: client, baseUrl: 'https://api.interna.setes.example', session: token), 'NETWORK · setes-api'),
          (NfseApiClient(client: client, baseUrl: 'https://nfse.interna.setes.example', session: token), 'NETWORK · nfse-api'),
        ];
        for (final (api, code) in clients) {
          final calls = <String, Future<Map<String, dynamic>> Function()>{
            'get': () => api.get('/api/x?filter=Jo%C3%A3o'),
            'post': () => api.post('/api/x', {'a': 1}),
            'put': () => api.put('/api/x/1', {'a': 1}),
            'delete': () => api.delete('/api/x/1'),
            'post seleção': () => api.post('/auth/select-institution', {'institutionId': 1}, overrideToken: 'jwt.de.selecao'),
          };
          for (final MapEntry(key: verb, value: call) in calls.entries) {
            Object? caught;
            try {
              await call();
            } catch (e) {
              caught = e;
            }
            final why = '$label · ${api.serviceLabel} · $verb';
            expect(caught, isA<NetworkFailure>(), reason: why);
            final f = caught as NetworkFailure;
            expect([f.message, f.supportRef, f.code, f.statusCode, f.fields], ['core.errors.network', code, null, null, isEmpty], reason: why);
            for (final text in [f.message, f.supportRef!, f.toString()]) {
              for (final leak in ['http', 'interna', 'Exception', 'Error', 'uri', '3000', 'jwt', 'token', 'Connection', 'Jo']) {
                expect(text, isNot(contains(leak)), reason: '$why vazou "$leak" em "$text"');
              }
            }
            checked++;
          }
        }
        expect(token.value, 'jwt.da.sessao', reason: 'a rede caída nunca derruba a sessão');
      }
      expect(checked, 50);
    });

    test('[RESISTIU] D-F148 intacto: o 401 da nfse-api pergunta ao EMISSOR; o `sessionAlive` do setes-api SEM rede "não prova a morte" (true) → `SESSION_NOT_ACCEPTED` com a origem, a sessão FICA; e a rede caída no próprio emissor nunca expira a sessão',
        () async {
      final token = ProductToken()..value = 'jwt.vivo';
      final erp = ApiClient(client: MockClient((_) async => throw _failedToFetch('https://api.interna/api/core/me')), baseUrl: 'https://api.interna', session: token);
      token.confirmer = erp.sessionAlive;
      final nfse = NfseApiClient(
        client: MockClient((_) async => http.Response(jsonEncode({'error': 'kid desconhecido', 'code': 'AUTH_INVALID_TOKEN'}), 401)),
        baseUrl: 'https://nfse.interna',
        session: token,
      );
      Object? caught;
      try {
        await nfse.get('/v1/nfse/invoices/1');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.sessionNotAccepted)
          .having((f) => f.supportRef, 'ref', 'AUTH_INVALID_TOKEN: kid desconhecido'));
      expect(caught, isNot(isA<UnauthorizedFailure>()));
      expect([await erp.sessionAlive(), token.value], [true, 'jwt.vivo']);
    });

    test('[RESISTIU] D-F139/D-F176 intactos: a rede caída na nfse-api (repositório REAL — a frase da D-F185, o ref NETWORK · nfse-api) segue DESCONHECIDA no ato (`isUnknownAuthorityOutcome`), a linha do lote fiscal fica "incerta" com `network` e SEM o ref (D-F180), e a saga para no fisco (stage authority) com a falha de rede',
        () async {
      final client = NfseApiClient(client: MockClient((_) async => throw _failedToFetch('https://nfse.interna/v1/nfse/invoices/1/transmit')),
          baseUrl: 'https://nfse.interna');
      final nfseRepo = ServiceOrderNfseRepositoryImpl(datasource: ServiceOrderNfseDatasourceImpl(client: client));
      final transmit = (await nfseRepo.transmit(1)).fold((f) => f, (_) => null)!;
      expect([transmit is NetworkFailure, transmit.message, transmit.supportRef, isUnknownAuthorityOutcome(transmit)],
          [true, 'forms.serviceOrder.fiscalNoResponse', 'NETWORK · nfse-api', true]);
      final report = await ServiceOrderFiscalTransmitBatch(repository: nfseRepo)([1]);
      final row = report.rows.single;
      expect([row.unknown, row.network, row.supportRef, row.uncertainDetail, row.httpStatus], [true, true, '', '', 0]);
      final invoice = InvoiceRepoMock();
      when(() => invoice.cancelPlan(1)).thenAnswer((_) async => const Right(ServiceOrderCancelPlan(orderId: 1, blocks: _authorizedBlocks)));
      final saga = await ServiceOrderCancelInvoice(nfse: nfseRepo, invoice: invoice)(1, 'motivo', atAuthority: true);
      final sf = saga.fold((l) => l, (_) => null)!;
      expect([sf.stage, sf.failure is NetworkFailure, isUnknownAuthorityOutcome(sf.failure), sf.authorityCancelled],
          [CancelSagaStage.authority, true, true, false]);
      verifyNever(() => invoice.cancel(any(), any()));
    });

    _superseded('[FATO PSO-ADV-03] os repositórios do CORE (auth ×5, menu, preferências ×2, tema ×2) viram QUALQUER erro que não é `Failure` em `NetworkFailure()` SEM o código: o setes-api que RESPONDEU 200 com uma página HTML (host/proxy trocado) dá, na troca de estabelecimento do login, "Sem resposta do serviço — rede, proxy ou tempo." e nenhum "Informe o código …" — a D-F204 diz "sem resposta" de quem respondeu, e a D-F205 não chega a essa falha',
        () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html>Plesk</html>', 200)), baseUrl: 'https://api.setes.example');
      final repo = AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api));
      final f = (await repo.selectInstitution('jwt.de.selecao', 1)).fold((l) => l, (_) => null)!;
      expect([f is NetworkFailure, f.message.tr(), f.supportRef, f.code], [true, 'Sem resposta do serviço — rede, proxy ou tempo.', null, null]);
      final sources = [
        '../../packages/core/lib/src/auth/data/repository/auth_repository_impl.dart',
        '../../packages/core/lib/src/menu/data/repository/menu_repository_impl.dart',
        '../../packages/core/lib/src/preference/data/repository/preference_repository_impl.dart',
        '../../packages/core/lib/src/theme/data/repository/theme_repository_impl.dart',
      ];
      final sites = sources.map((p) => RegExp(r'catch \(_\) \{\s*return const Left\(NetworkFailure\(\)\);').allMatches(File(p).readAsStringSync()).length);
      expect(sites.toList(), [5, 1, 2, 2]);
    });

    test('[CORRIGIDO D-F210 — invalidResponseFailure no core — era o ACHADO PSO-ADV-03 LOW] a resposta que o core não consegue ler (200 sem o envelope) é falha TÉCNICA da resposta (`CLIENT_INVALID_RESPONSE` com o texto no ref — a peça `invalidResponseFailure`), nunca "sem resposta do serviço"',
        () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html>Plesk</html>', 200)), baseUrl: 'https://api.setes.example');
      final f = (await AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).selectInstitution('jwt.de.selecao', 1))
          .fold((l) => l, (_) => null)!;
      expect([f is NetworkFailure, f.code], [false, ClientFailureCodes.invalidResponse]);
    });

    final sdkPatch = _dart2jsDeveloperPatch();
    _superseded('[FATO PSO-ADV-04] "a exceção crua do Dart (com a URL interna) vai só para o LOG": no build que vai ao ar (`flutter build web --release` — dart2js, `build-web.ps1`) o `developer.log` é um NO-OP (o patch do dart2js tem o corpo `// TODO.`; só o DDC do `flutter run` escreve `console.debug`) — em produção o texto não vai a lugar nenhum. A pista que sobra é o console do NAVEGADOR (o erro de CORS/rede com a URL é dele, não do app)',
        () {
      final patch = File(sdkPatch!).readAsStringSync();
      final logBody = patch.substring(patch.indexOf('void log('), patch.indexOf('@patch', patch.indexOf('void log(')));
      expect([logBody.contains('// TODO.'), logBody.contains('console')], [true, false]);
      expect(File('build-web.ps1').readAsStringSync(), contains('flutter build web --release'));
      expect(File('build-web.ps1').readAsStringSync(), isNot(contains('--wasm')));
      final core = File(_coreClientSrc).readAsStringSync();
      expect(core, contains("developer.log('falha de rede em \$serviceLabel \$path: \$e', name: 'ApiClient');"));
    }, skip: sdkPatch == null ? 'SDK do Flutter não localizado (dart-sdk/lib/_internal/js_runtime/lib/developer_patch.dart)' : false);

    test('[DECIDIDO D-F211 — era o FATO PSO-ADV-06] D-F205 torna IGUAIS as falhas de rede do mesmo serviço (o ref era a exceção com a URL — única por rota): o one-shot igual ao anterior é DESCARTADO (D-F198) — dois atos DIFERENTES da OS (XML e DANFSe), concluídos sem resposta com a tela já em outro lugar, viram UM diálogo "OS N: …" (antes da D-F205 eram dois)',
        () async {
      Future<int> run(Failure xmlFailure, Failure danfseFailure) async {
        final repo = ServiceOrderRepoMock();
        final nfse = NfseRepoMock();
        final invoice = InvoiceRepoMock();
        when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
            .thenAnswer((_) async => Right(_listPage([_aId])));
        when(() => repo.getById(_aId)).thenAnswer((_) async => const Right(_a));
        when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoice));
        when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) async => const Right(_aEffect));
        final xml = Completer<Either<Failure, String>>();
        final danfse = Completer<Either<Failure, String>>();
        when(() => nfse.xml(_aId)).thenAnswer((_) => xml.future);
        when(() => nfse.danfse(_aId)).thenAnswer((_) => danfse.future);
        final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
        final states = <ServiceOrderState>[];
        final sub = bloc.stream.listen(states.add);
        for (final e in [const ServiceOrderListRequested(status: 'F', filter: ''), const ServiceOrderViewRequested(_aId),
          const ServiceOrderFiscalXmlRequested(_aId), const ServiceOrderFiscalDanfseRequested(_aId), const ServiceOrderBackToListPressed()]) {
          bloc.add(e);
          await pumpEventQueue(times: 20);
        }
        xml.complete(Left(xmlFailure));
        await pumpEventQueue(times: 20);
        danfse.complete(Left(danfseFailure));
        await pumpEventQueue(times: 20);
        await sub.cancel();
        await bloc.close();
        return states.whereType<ServiceOrderActionFailure>().where((s) => s.orderNumber != null).length;   // "OS N: …" (a tela já é a lista)
      }

      expect(await run(_nfseDownRepo, _nfseDownRepo), 1);   // hoje (D-F205): iguais → o 2º desfecho some
      expect(
          await run(
            const NetworkFailure(message: 'forms.serviceOrder.fiscalNoResponse', detail: 'ClientException: Failed to fetch, uri=…/xml'),
            const NetworkFailure(message: 'forms.serviceOrder.fiscalNoResponse', detail: 'ClientException: Failed to fetch, uri=…/danfse'),
          ),
          2);   // antes da D-F205: o ref (a URL) os distinguia
    });

    test('[DECIDIDO D-F212 — era o FATO PSO-ADV-07] o código curto NÃO chega aos avisos do ato fiscal: o desfecho desconhecido (`ServiceOrderFiscalNotice`) leva só a MENSAGEM no `detail` — "resultado incerto … / Sem resposta do serviço …" sem "NETWORK · nfse-api" (a linha do lote também não o leva — D-F176/D-F180, decidido)',
        () async {
      final repo = ServiceOrderRepoMock();
      final nfse = NfseRepoMock();
      final invoice = InvoiceRepoMock();
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => Right(_listPage([_aId])));
      when(() => repo.getById(_aId)).thenAnswer((_) async => const Right(_a));
      when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoice));
      when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) async => const Right(_aEffect));
      when(() => nfse.transmit(_aId)).thenAnswer((_) async => Left(_nfseDownRepo));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      for (final e in [const ServiceOrderListRequested(status: 'F', filter: ''), const ServiceOrderViewRequested(_aId),
        const ServiceOrderTransmitRequested(_aId)]) {
        bloc.add(e);
        await pumpEventQueue(times: 20);
      }
      await sub.cancel();
      await bloc.close();
      final notice = states.whereType<ServiceOrderFiscalNotice>().single;
      expect([notice.messageKey, notice.detail, notice.props.any((p) => '$p'.contains('NETWORK'))],
          ['forms.serviceOrder.fiscalOutcomeUnknown', 'forms.serviceOrder.fiscalNoResponse', false]);
    });
  });

  // ---------------------------------------------------------------------
  // 4. P-04 — o texto final com `fields[]` sem âncora (o listener REAL da página)
  // ---------------------------------------------------------------------
  group('P-04 × as formas REAIS dos produtores (o diálogo da página de OS)', () {
    /// Entrega cada falha ao listener da página pelo caminho mais curto (a carga da lista) e lê o texto do diálogo de validação.
    Future<List<String>> textsOf(WidgetTester tester, List<Failure> failures) async {
      final repo = ServiceOrderRepoMock();
      var n = 0;
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => Left(failures[n++]));
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      final out = <String>[];
      for (var i = 0; i < failures.length; i++) {
        final texts = _dialogTexts(tester);
        expect(texts.first, 'Atenção', reason: 'diálogo de VALIDAÇÃO (${failures[i].code})');
        out.add(texts[1]);
        await tester.tap(find.text('OK'));
        await _settle(tester);
        if (i < failures.length - 1) {
          await tester.tap(find.text('Tentar novamente'));
          await _settle(tester);
        }
      }
      await dispose();
      return out;
    }

    // nfse-api/src/facts/service-facts.ts:270 (o caso do passeio) · setes-api shared/invoice/invoice-cancel-waiver.ts:84 (error == campo)
    const municipal = Failure(
        message: 'Código de tributação municipal "0102" fora da forma do DPS (cTribMun = 3 dígitos) — corrija a regra de ISS',
        statusCode: 422, code: 'FISCAL_DPS_INVALID', fields: [FailureField(field: 'municipalCode', message: 'Esperado 3 dígitos')]);
    const waiver = Failure(
        message: 'Nota não está substituída no fisco', statusCode: 409, code: 'INVOICE_CANCEL_WAIVER_NOT_APPLICABLE',
        fields: [FailureField(field: 'fiscal', message: 'Nota não está substituída no fisco')]);
    const noError = Failure(message: 'core.errors.generic', statusCode: 422, fields: [FailureField(field: 'x', message: 'Obrigatório')]);
    // nfse-api/src/nfse/transmission.ts:192 (`DPS inválido: ${msg}` + field dps = msg) e :882 (`Fisco recusou o cancelamento: ${authorityMessage}`
    // — authorityMessage = as mensagens dos fields juntas — + fields = os códigos do fisco)
    const dpsBuilder = Failure(
        message: 'DPS inválido: cTribMun: valor fora do padrão', statusCode: 422, code: 'FISCAL_DPS_INVALID',
        fields: [FailureField(field: 'dps', message: 'cTribMun: valor fora do padrão')]);
    const cancelRefused = Failure(
        message: 'Fisco recusou o cancelamento: Prazo de cancelamento expirado', statusCode: 409, code: 'FISCAL_CANCEL_REFUSED',
        fields: [FailureField(field: 'E1235', message: 'Prazo de cancelamento expirado')]);
    // setes-api shared/http/controller-utils.ts:96 (parseBody — o 400 de DTO)
    const dto = Failure(
        message: 'Validação falhou', statusCode: 400, code: 'VALIDATION_FAILED',
        fields: [FailureField(field: 'dtExpiration', message: 'Data inválida')]);

    testWidgets('[RESISTIU] o caso do passeio (422 FISCAL_DPS_INVALID do cTribMun): principal + "• Esperado 3 dígitos"; `error` == campo (409 do "manter a nota"): UMA vez; a principal que é CHAVE i18n (`core.errors.generic`) sai traduzida',
        (tester) async {
      final texts = await textsOf(tester, [municipal, waiver, noError]);
      expect(texts, [
        'Código de tributação municipal "0102" fora da forma do DPS (cTribMun = 3 dígitos) — corrija a regra de ISS\n• Esperado 3 dígitos',
        'Nota não está substituída no fisco',
        'Não foi possível concluir a operação\n• Obrigatório',
      ]);
    });

    _supersededWidgets('[FATO PSO-ADV-08] a mensagem do campo REPETIDA quando a principal já a contém — os dois produtores da nfse-api que montam `error` A PARTIR dos fields (o leiaute do DPS que o montador recusa; o cancelamento que o fisco recusa); a comparação é só por IGUALDADE. E o 400 de DTO do setes-api sai "Validação falhou • Data inválida" — sem o NOME do campo, que a skill mensagem-e-validacao pede no sem-âncora (`showUnanchoredServerField`: campo + mensagem), e o código do fisco (E1235) também não aparece',
        (tester) async {
      final texts = await textsOf(tester, [dpsBuilder, cancelRefused, dto]);
      expect(texts, [
        'DPS inválido: cTribMun: valor fora do padrão\n• cTribMun: valor fora do padrão',
        'Fisco recusou o cancelamento: Prazo de cancelamento expirado\n• Prazo de cancelamento expirado',
        'Validação falhou\n• Data inválida',
      ]);
      expect(File(_pageSrc).readAsStringSync(), contains(r"showValidationFeedback(context, '$about${main == field ? main : '$main\n• $field'}');"));
    });

    testWidgets('[CORRIGIDO D-F209 — unanchoredFieldsText — era o ACHADO PSO-ADV-08 LOW] a mensagem do campo aparece UMA vez quando a principal já a contém', (tester) async {
      final texts = await textsOf(tester, [dpsBuilder, cancelRefused]);
      for (final t in texts) {
        final field = t.contains('cTribMun') ? 'cTribMun: valor fora do padrão' : 'Prazo de cancelamento expirado';
        expect(field.allMatches(t).length, 1, reason: t);
      }
    });

    testWidgets('[DECIDIDO D-F209 (= PSO-SOC-03 (a)) — os TRÊS casos do texto sem âncora] (1) 422 de domínio (o caso do passeio): a '
        'mensagem PRINCIPAL + a do campo; (2) 400 de DTO (`VALIDATION_FAILED`, "Validação falhou" genérico): o campo + a mensagem dele no '
        'formato da peça `showUnanchoredServerField` — sem o genérico; (3) a principal IGUAL à do campo: aparece uma vez', (tester) async {
      final texts = await textsOf(tester, [municipal, dto, waiver]);
      expect(texts[0], 'Código de tributação municipal "0102" fora da forma do DPS (cTribMun = 3 dígitos) — corrija a regra de ISS\n'
          '• Esperado 3 dígitos');
      expect(texts[1], 'Campo "dtExpiration": Data inválida');
      expect(texts[2], 'Nota não está substituída no fisco');
    });
  });

  // ---------------------------------------------------------------------
  // 5. D-F204 — a frase neutra nas duas línguas (sem resíduo)
  // ---------------------------------------------------------------------
  test('[RESISTIU] D-F204: `core.errors.network` = a frase da D-F185/D-F181 nas DUAS línguas (pt e en iguais às dos atos fiscais); nenhuma tradução fala em "conexão com o servidor"/"connection failure"; `register.loadFailed`/`retry` existem nas duas',
      () {
    String at(Map<String, dynamic> m, String path) => path.split('.').fold<dynamic>(m, (v, k) => (v as Map)[k]) as String;
    for (final m in [pt, en]) {
      expect(at(m, 'core.errors.network'), at(m, 'forms.serviceOrder.fiscalNoResponse'));
      expect(at(m, 'register.loadFailed'), isNotEmpty);
      expect(at(m, 'register.retry'), isNotEmpty);
    }
    final raw = File('assets/translations/pt.json').readAsStringSync() + File('assets/translations/en.json').readAsStringSync();
    for (final old in ['Falha de conexão', 'conexão com o servidor', 'Connection failure', 'with the server']) {
      expect(raw, isNot(contains(old)), reason: old);
    }
  });
}

/// O `developer_patch.dart` do dart2js no SDK do Flutter que roda este teste (null = não achado).
String? _dart2jsDeveloperPatch() {
  const rel = 'dart-sdk/lib/_internal/js_runtime/lib/developer_patch.dart';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final r?) '$r/bin/cache',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    roots.add(dir.path);
    roots.add('${dir.path}/bin/cache');
    dir = dir.parent;
  }
  for (final r in roots) {
    final f = File('$r/$rel');
    if (f.existsSync()) return f.path;
  }
  return null;
}
