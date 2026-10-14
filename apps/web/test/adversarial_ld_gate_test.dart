// GATE ADVERSARIAL independente do ÚLTIMO DELTA da F2b (setes-app) — alvo: `f312f06..60df1df` (branch f2b, commit 60df1df — "Gates do
// passeio: D-F208…D-F212 + trava com dono + envelope da lista de OS"):
//   - `_RunLock` (trava COM DONO) nas 4 operações longas do bloc de OS (rotina mensal, fotografia das pendentes, lote de faturamento,
//     lote fiscal) no lugar dos booleanos — PSO-ADV-09;
//   - D-F208 (`debugPrint` no `ProductApiClient`), D-F209 (`unanchoredFieldsText` na ponte), D-F210 (`invalidResponseFailure` nos 10
//     fallbacks dos 4 repositórios do core);
//   - `envelopePage` na lista de OS (PSO-ADV-05); estado de falha com page/pageSize (PSO-ADV-01); a seleção ignora `loadFailed`
//     (PSO-ADV-02); `.tr()` nas linhas do relatório do lote de faturamento (PSO-SOC-04).
//
// O que o delta PROMETE e este gate ataca: (1) nunca duas execuções da MESMA operação longa no ar; a fotografia nunca com o lote fiscal no
// ar; a lista sai em loading enquanto QUALQUER operação longa está no ar (D-F169, SEM a tolerância do PSO-ADV-09 que o fuzz do passeio
// ainda modela); toda trava solta no repouso — com recargas finais lentas, falhas, exceções, `stopBatches`, bloc fechado e duplo clique;
// (2) erro de LEITURA nunca é "rede" nos repositórios do core, e a rede caída continua `NETWORK · setes-api`; (3) o texto sem âncora nas
// formas reais dos produtores; (4) a lista de OS com 200 fora do envelope = falha da carga, nunca "nenhum registro"; (5) o "Tentar
// novamente" volta à mesma página e tamanho.
//
// Convenção do gate (a mesma dos gates R5–R16 e do passeio):
//   - `[ACHADO LD-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_ld_gate_test.dart
//   - `[FATO LD-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada achado/limite.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail; o `ApiClient` DE VERDADE sobre o `MockClient` do package:http; a página de OS montada
// de verdade (Modular com binds de teste).
//
// RESULTADO (2026-10-13): sem HIGH/CRITICAL. O `_RunLock` RESISTIU — 600 sequências de fuzz (300 pela página + 300 com eventos diretos;
// ~4.000 operações longas começadas, ~315 instantes "o `finally` antigo roda com a operação seguinte do mesmo tipo no ar" nos 4 tipos)
// sob oráculos ESTRITOS (sem a tolerância do PSO-ADV-09), o PSO-ADV-09 dirigido nos 4 tipos × recarga velha ok/504, duplo/triplo clique,
// exceção não tratada, `stopBatches` com o bloc vivo e bloc fechado; `envelopePage`, a página/tamanho do "Tentar novamente", o `.tr()` do
// relatório e o `debugPrint` também. ACHADOS: LD-ADV-01 MEDIUM (login com 200 sem token prende o `AuthLoading` — anterior ao delta, no
// alcance prometido pela D-F210); LOW: LD-ADV-03 (200 torto = sucesso calado em me/menus/preferências/tema), LD-ADV-04 (o repositório da
// OS põe o texto do Dart na MENSAGEM, sem código), LD-ADV-05 (a guarda da fotografia é de um lado só — só por evento direto), LD-ADV-06
// (rotina mensal/pendentes pedem a lista depois do close), LD-ADV-07 (o corte de 255 do `authorityMessage` no ramo `all`), LD-ADV-08
// (`unanchoredFieldsText` não é total; o ramo do DTO decide só pelo código), LD-ADV-09 (o mesmo `CLIENT_INVALID_RESPONSE` sai "Atenção" ou
// "Erro" conforme o caminho), LD-ADV-10 (a recursão "página esvaziou" sem limite — anterior, ~28 listas), LD-ADV-11 (a seleção sobrevive à
// troca de página/filtro que FALHA — reaberto pela correção do PSO-ADV-02), LD-ADV-12 (método: o fuzz do gate do passeio AINDA modela o
// PSO-ADV-09 — marcou 177 instantes "finally antigo baixou a marca" e aceitaria `loading: false` neles; uma regressão da trava passaria
// por lá — este gate cobre com o oráculo estrito). FATO LD-ADV-02: o diálogo do login mostra o texto do Dart no ref (a regra decidida da
// F2B-ADV-12).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
// ignore: implementation_imports
import 'package:core/src/auth/presentation/content/auth_feedback.dart';
import 'package:dartz/dartz.dart' hide Bind;
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
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/page/service_order_page.dart';
import 'package:setes_web/app/shared/feedback/form_pendency.dart';
import 'package:setes_web/app/shared/search/search_criteria_datasource.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

import 'support/service_order_bloc_factory.dart';

const _blocSrc = 'lib/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';
const _osRepoSrc = 'lib/app/modules/service_orders/data/repository/service_order_repository_impl.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

const _newId = 77;
const _aId = 7374;
const _newOrder = ServiceOrderFull(id: _newId, number: 8001, customerId: 5);
const _a = ServiceOrderFull(id: _aId, number: 77, customerId: 1, status: 'F');
const _aVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
const _aEffect = ServiceOrderFiscalEffect();

final _erpDown = NetworkFailure(detail: networkFailureCode('setes-api'));
const _internal = Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'R-500');

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

PagedResult<ServiceOrderListItem> _listPage(List<int> ids, {int page = 1, int pageSize = 10, int? total}) => PagedResult(items: [
      for (final id in ids) ServiceOrderListItem(id: id, number: 7000 + id, customerId: id, customerName: 'Cliente $id', status: 'A'),
    ], page: page, pageSize: pageSize, total: total ?? ids.length);

// =====================================================================================================================================
// Rig do bloc: TODA resposta fica ESTACIONADA (Completer) até o teste concluí-la — a ordem de chegada é do teste.
// =====================================================================================================================================

/// As operações LONGAS (o `_batchInFlight` do bloc) — o tipo da resposta estacionada que é o trabalho PRINCIPAL de cada uma.
const _longKinds = ['monthly', 'batch', 'pending', 'ftransmit'];

class _Flight {
  _Flight(this.kind, this.finish);
  final String kind;
  final void Function(Failure? failure) finish;
}

class _Rig {
  _Rig() {
    when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((inv) {
      listCalls++;
      if (closed) listCallsAfterClose++;
      final page = inv.namedArguments[#page] as int;
      final size = inv.namedArguments[#pageSize] as int?;
      listArgs.add((page, size));
      return park('list', () => _listPage([_newId, _aId], page: page, pageSize: size ?? 10, total: 30));
    });
    when(() => repo.getById(_newId)).thenAnswer((_) => park('get', () => _newOrder));
    when(() => repo.getById(_aId)).thenAnswer((_) => park('get', () => _a));
    when(() => nfse.getView(_aId)).thenAnswer((_) => park('voice', () => _aVoice));
    when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) => park('effect', () => _aEffect));
    when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
    when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) {
      final ids = inv.positionalArguments[0] as List<int>;
      return park('batch', () => BatchInvoiceReport.fromEntries([for (final id in ids) BatchInvoiceEntry(orderId: id, ok: true)]));
    });
    when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => park('pending',
        () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId, number: '9001')], page: 1, pageSize: 100, total: 1)));
    when(() => nfse.transmit(any())).thenAnswer((inv) {
      final id = inv.positionalArguments[0] as int;
      return park('ftransmit', () => ServiceOrderTransmitResult(invoiceId: id, attempt: 1));
    });
    when(() => repo.invoice(_newId, any())).thenAnswer((_) => park('act', () => const ServiceOrderInvoiceResult(invoiceNumber: '1')));
    when(() => repo.itemPost(_newId, any())).thenAnswer((_) => park('act', () => 1));
    bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    sub = bloc.stream.listen((s) {
      states.add(s);
      stepEmits.add(s);
    });
  }

  final repo = ServiceOrderRepoMock();
  final nfse = NfseRepoMock();
  final invoice = InvoiceRepoMock();
  late final ServiceOrderBloc bloc;
  late final StreamSubscription<ServiceOrderState> sub;
  final flights = <_Flight>[];
  final states = <ServiceOrderState>[];
  final stepEmits = <ServiceOrderState>[];
  final listArgs = <(int, int?)>[];
  var listCalls = 0;
  var listCallsAfterClose = 0;
  var closed = false;

  Future<Either<Failure, T>> park<T>(String kind, T Function() ok) {
    final c = Completer<Either<Failure, T>>();
    flights.add(_Flight(kind, (f) => c.complete(f == null ? Right(ok()) : Left(f))));
    return c.future;
  }

  Future<void> pump() => pumpEventQueue(times: 30);

  Future<void> add(ServiceOrderEvent e) async {
    bloc.add(e);
    await pump();
  }

  int parked(String kind) => flights.where((f) => f.kind == kind).length;
  bool longParked() => flights.any((f) => _longKinds.contains(f.kind));

  /// Conclui a resposta estacionada do tipo [kind] (a mais ANTIGA; [latest] = a mais nova).
  Future<void> finish(String kind, {Failure? failure, bool latest = false}) async {
    final list = flights.where((f) => f.kind == kind).toList();
    expect(list, isNotEmpty, reason: 'nenhuma resposta "$kind" estacionada');
    final f = latest ? list.last : list.first;
    flights.remove(f);
    f.finish(failure);
    await pump();
  }

  Future<void> drain({int cap = 400}) async {
    for (var i = 0; i < cap && flights.isNotEmpty; i++) {
      flights.removeAt(0).finish(null);
      await pump();
    }
  }

  ServiceOrderState? shown() => states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
  ServiceOrderListState lastList() => states.whereType<ServiceOrderListState>().last;

  Future<void> close() async {
    closed = true;
    await sub.cancel();
    await bloc.close();
  }
}

ServiceOrderEvent _longEvent(String kind, {List<int> batchIds = const [_newId], List<int> fiscalIds = const [_aId]}) => switch (kind) {
      'monthly' => const ServiceOrderMonthlyRunRequested(year: 2026, month: 10),
      'batch' => ServiceOrderBatchInvoiceRequested(orderIds: batchIds, input: _input),
      'pending' => const ServiceOrderFiscalPendingRequested(),
      _ => ServiceOrderFiscalTransmitBatchRequested(fiscalIds),
    };

class _Out {
  final violations = <String>[];
  final counts = <String, int>{};
  void count(String k) => counts[k] = (counts[k] ?? 0) + 1;
}

/// FUZZ da trava com dono. [pageModel] = só o que a PÁGINA deixa fazer (botão longo só com a lista à vista e fora de loading — o
/// `state.loading ? null` —, "Transmitir pendentes" só na aba F e "Faturar selecionadas" só na A, o lote fiscal só a partir do diálogo
/// MODAL que a fotografia abre, duplo clique = o mesmo evento 2× no mesmo quadro); senão, eventos DIRETOS em qualquer ordem.
Future<void> _lockFuzz(int seed, _Out out, {required bool pageModel, int steps = 50}) async {
  final rnd = Random(seed);
  final rig = _Rig();
  final finalReloadOf = <_Flight, String>{};
  var dialog = false;   // modelo da página: o diálogo de confirmação das pendentes (modal) está aberto
  var dialogSeen = 0;
  String why(int step, String what) => '${pageModel ? 'página' : 'direto'} semente $seed passo $step: $what';
  List<int> batchIds() => rnd.nextInt(4) == 0 ? [for (var i = 1; i <= batchInvoiceChunkSize + 1; i++) 1000 + i] : const [_newId];
  List<int> fiscalIds() => rnd.nextInt(3) == 0 ? const [_aId, _newId] : const [_aId];
  ServiceOrderEvent long(String k) => _longEvent(k, batchIds: batchIds(), fiscalIds: fiscalIds());

  List<ServiceOrderEvent> pickRaw() {
    switch (rnd.nextInt(12)) {
      case 0:
      case 1:
        return [ServiceOrderListRequested(status: const [null, 'A', 'F'][rnd.nextInt(3)], page: 1 + rnd.nextInt(3),
            pageSize: const [null, 10, 25][rnd.nextInt(3)], filter: const [null, '', 'x'][rnd.nextInt(3)])];
      case 2:
        return [ServiceOrderViewRequested(rnd.nextBool() ? _newId : _aId)];
      case 3:
        return [const ServiceOrderBackToListPressed()];
      case 4:
      case 5:
      case 6:
      case 7:
        return [long(_longKinds[rnd.nextInt(4)])];
      case 8:
        return [const ServiceOrderInvoiceRequested(orderId: _newId, input: _input)];
      case 9:
        return [const ServiceOrderItemSaveRequested(orderId: _newId, input: _item)];
      case 10:
        final k = _longKinds[rnd.nextInt(4)];
        return [long(k), long(k)];   // duplo clique
      default:
        final a = _longKinds[rnd.nextInt(4)];
        final b = _longKinds[rnd.nextInt(4)];
        return [long(a), long(b)];   // duas operações longas no mesmo quadro
    }
  }

  List<ServiceOrderEvent> pickPage() {
    final s = rig.shown();
    if (dialog) {
      dialog = false;
      return rnd.nextBool() ? [ServiceOrderFiscalTransmitBatchRequested(fiscalIds())] : const [];   // "Transmitir" × "Cancelar"
    }
    final idle = s is ServiceOrderListState && !s.loading;
    switch (rnd.nextInt(10)) {
      case 0:
      case 1:
      case 2:
        // a TabBar segue viva no loading; a barra de paginação só com a lista carregada
        return [
          if (rnd.nextBool() || !idle)
            ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F')
          else
            ServiceOrderListRequested(page: 1 + rnd.nextInt(3))
        ];
      case 3:
        return s is ServiceOrderListState && !s.loading && s.items.isNotEmpty
            ? [ServiceOrderViewRequested(rnd.nextBool() ? _newId : _aId)]
            : const [];
      case 4:
        return s is ServiceOrderDetailState ? [const ServiceOrderBackToListPressed()] : const [];
      case 9:
        return s is ServiceOrderDetailState && !s.saving && s.order.id == _newId
            ? [rnd.nextBool() ? const ServiceOrderInvoiceRequested(orderId: _newId, input: _input) : const ServiceOrderItemSaveRequested(orderId: _newId, input: _item)]
            : const [];
      default:
        if (!idle) return const [];
        final st = s.status;
        final options = ['monthly', if (st == 'A') 'batch', if (st == 'F') 'pending'];
        final k = options[rnd.nextInt(options.length)];
        final e = long(k);
        return rnd.nextInt(3) == 0 ? [e, e] : [e];   // duplo clique no mesmo quadro (o botão ainda não reconstruiu)
    }
  }

  await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));   // o initState da página
  for (var step = 0; step < steps + 400; step++) {
    final draining = step >= steps;
    if (draining && rig.flights.isEmpty) break;
    rig.stepEmits.clear();
    final before = rig.flights.toSet();
    var userStep = false;
    _Flight? done;
    if (rig.flights.isNotEmpty && (draining || rnd.nextInt(10) < 5)) {
      done = rig.flights.removeAt(rnd.nextInt(rig.flights.length));
      final fail = !draining && rnd.nextInt(3) == 0;
      done.finish(fail ? (rnd.nextBool() ? _erpDown : _internal) : null);
      // a recarga final de uma operação longa termina AGORA com outra do MESMO tipo no ar — o instante em que o `finally` do booleano
      // antigo apagava a trava da seguinte (PSO-ADV-09): os oráculos abaixo seguem valendo depois dele
      final owner = finalReloadOf.remove(done);
      if (owner != null && rig.parked(owner) > 0) out.count('finally antigo com $owner no ar');
    } else {
      final events = pageModel ? pickPage() : pickRaw();
      if (events.isEmpty) continue;
      userStep = true;
      for (final e in events) {
        rig.bloc.add(e);
      }
    }
    await rig.pump();
    if (rig.stepEmits.any((s) => s is ServiceOrderFiscalPendingLoaded)) {
      dialog = true;
      dialogSeen++;
    }
    final fresh = rig.flights.where((f) => !before.contains(f)).toList();
    final finished = done;
    if (finished != null && _longKinds.contains(finished.kind) && rig.parked(finished.kind) == 0) {
      for (final f in fresh.where((f) => f.kind == 'list')) {
        finalReloadOf[f] = finished.kind;   // a recarga final desta operação (o `finally` dela espera esta resposta)
      }
    }
    // (O1) nunca duas execuções da MESMA operação longa no ar
    for (final k in _longKinds) {
      if (rig.parked(k) > 1) out.violations.add(why(step, '(O1) ${rig.parked(k)} "$k" no ar'));
    }
    // (O2) a fotografia nunca COMEÇA com o lote fiscal no ar
    final oldTransmit = rig.flights.any((f) => f.kind == 'ftransmit' && before.contains(f));
    if (fresh.any((f) => f.kind == 'pending') && oldTransmit) out.violations.add(why(step, '(O2) fotografia com o lote fiscal no ar'));
    // (O2b) o lote fiscal começando com a fotografia no ar — o bloc não guarda este lado (a página: o lote nasce do diálogo MODAL)
    final oldPending = rig.flights.any((f) => f.kind == 'pending' && before.contains(f));
    if (userStep && fresh.any((f) => f.kind == 'ftransmit') && oldPending) {
      if (pageModel) {
        out.violations.add(why(step, '(O2b) lote fiscal com a fotografia no ar PELA PÁGINA'));
      } else {
        out.count('LD-ADV-05 lote fiscal começou com a fotografia no ar (evento direto)');
      }
    }
    // (O3) D-F169 ESTRITO: toda lista carregada/falhada sai com loading = operação longa no ar (sem a tolerância do PSO-ADV-09)
    for (final s in rig.stepEmits.whereType<ServiceOrderListState>()) {
      if (s.items.isEmpty && !s.loadFailed) continue;   // o loading de começo de recarga
      if (s.loading != rig.longParked()) {
        out.violations.add(why(step, '(O3) lista ${s.loadFailed ? 'FALHADA' : 'carregada'} com loading ${s.loading} e operação longa no ar = '
            '${rig.longParked()} (${rig.flights.map((f) => f.kind).toList()})'));
      }
      if (s.loading) out.count('lista com loading sob operação longa');
    }
    for (final k in _longKinds) {
      if (fresh.any((f) => f.kind == k) && userStep) out.count('começou $k');
    }
  }
  if (rig.flights.isNotEmpty) out.violations.add('semente $seed: ${rig.flights.length} respostas nunca concluídas');
  // (O4) repouso: nada preso — nenhum spinner sem operação e cada trava solta
  final s = rig.shown();
  if (s is ServiceOrderListState && s.loading) out.violations.add('semente $seed: (O4) spinner preso no repouso: $s');
  for (final k in _longKinds) {
    rig.stepEmits.clear();
    await rig.add(_longEvent(k));
    if (rig.parked(k) != 1) out.violations.add('semente $seed: (O4) trava "$k" presa no repouso');
    await rig.drain();
  }
  final end = rig.shown();
  if (end is ServiceOrderListState && end.loading) out.violations.add('semente $seed: (O4) spinner preso depois do repouso');
  if (dialogSeen > 0) out.count('diálogo das pendentes');
  await rig.close();
}

// =====================================================================================================================================
// Página de verdade (molde do gate do passeio)
// =====================================================================================================================================

class _OsDsMock extends Mock implements ServiceOrderDatasource {}

class _SearchDsMock extends Mock implements SearchCriteriaDatasource {}

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

  addTearDown(destroy);
  await tester.pumpWidget(const MaterialApp(home: ServiceOrderPage(title: 'Ordens de Serviço')));
  await _settle(tester);
  return () async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(bloc.close);
    destroy();
  };
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

List<String> _dialogTexts(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '',
    ];

class _Prefs extends LocalPrefs {
  @override
  Future<void> setKeepConnected(bool value) async {}
  @override
  Future<int?> getDefaultInstitutionId() async => null;
  @override
  Future<void> setDefaultInstitutionId(int? institutionId) async {}
  @override
  Future<void> setSessionToken(String? token) async {}
}

/// Corre [body] numa zona que GUARDA os erros não tratados (o `rethrow` do handler do bloc) em vez de derrubar o teste.
Future<List<Object>> _guarded(Future<void> Function() body) async {
  final errors = <Object>[];
  final done = Completer<void>();
  runZonedGuarded(() async {
    try {
      await body();
    } finally {
      done.complete();
    }
  }, (e, _) => errors.add(e));
  await done.future;
  return errors;
}

/// As PROVAS de antes das correções da sessão (gates do último delta, 2026-10-13): o comportamento que cada FATO registrava não existe
/// mais; ficam PULADAS como histórico — o [CORRIGIDO] de cada achado prova o novo. Para revê-las: `flutter test --run-skipped …` (falham).
const _supersededReason = 'prova de ANTES da correção da sessão (gates do último delta) — o [CORRIGIDO] do achado prova o comportamento novo';
void _superseded(String name, dynamic Function() body, {Timeout? timeout}) =>
    test('[SUPERADO] $name', body, skip: _supersededReason, timeout: timeout);
void _supersededWidgets(String name, WidgetTesterCallback body, {Timeout? timeout}) =>
    testWidgets('[SUPERADO] $name', body, skip: true, timeout: timeout);   // _supersededReason

void main() {
  final pt = _load('pt');

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 1. `_RunLock` — a trava COM DONO das 4 operações longas
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('_RunLock × fuzz e sequências dirigidas', () {
    test('[RESISTIU] fuzz PELA PÁGINA (300 sementes) e por EVENTOS DIRETOS (300 sementes): (O1) nunca duas execuções da MESMA operação '
        'longa no ar; (O2) a fotografia nunca começa com o lote fiscal no ar; (O3) D-F169 ESTRITO — toda lista carregada OU falhada sai '
        'com `loading` = operação longa no ar (sem a tolerância que o fuzz do passeio ainda modela para o PSO-ADV-09); (O4) no repouso '
        'nenhum spinner preso e cada uma das 4 travas toma de novo', () async {
      final out = _Out();
      final seeds = int.tryParse(Platform.environment['LD_SEEDS'] ?? '') ?? 300;
      for (var seed = 1; seed <= seeds; seed++) {
        await _lockFuzz(seed, out, pageModel: true);
        await _lockFuzz(10000 + seed, out, pageModel: false);
      }
      // ignore: avoid_print
      print('fuzz _RunLock: ${out.counts}');
      expect(out.violations.take(10).toList(), isEmpty);
      for (final k in ['começou monthly', 'começou batch', 'começou pending', 'começou ftransmit', 'lista com loading sob operação longa',
        'diálogo das pendentes', for (final k in _longKinds) 'finally antigo com $k no ar']) {
        expect(out.counts[k] ?? 0, greaterThan(0), reason: k);
      }
    }, timeout: const Timeout(Duration(minutes: 8)));

    /// PSO-ADV-09 nas QUATRO operações (o gate do passeio provou só o lote fiscal): a op 1 termina o trabalho e a recarga final dela fica
    /// PRESA; o operador troca de aba (lista nova LIVRE — certo); a op 2 do MESMO tipo começa; a recarga velha enfim volta (ok ou 504) e o
    /// `finally` da op 1 roda. Devolve (lista pedida no meio da op 2 saiu em loading?, a op 3 entrou?, a op 4 no repouso entrou?, para o
    /// lote fiscal: a fotografia passou com o lote 2 no ar?).
    Future<(bool, bool, bool, bool)> oldFinally(String kind, {required bool slowFails}) async {
      final rig = _Rig();
      await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await rig.finish('list');
      await rig.add(_longEvent(kind));                       // op 1
      await rig.finish(kind);                                // o trabalho da op 1 acabou → a trava solta ANTES da recarga final
      final slow = rig.flights.lastWhere((f) => f.kind == 'list');   // a recarga final da op 1 — presa no proxy
      await rig.add(const ServiceOrderListRequested(status: 'F'));  // troca de aba
      await rig.finish('list', latest: true);
      await rig.add(_longEvent(kind));                       // op 2 — a trava é dela
      rig.flights.remove(slow);
      slow.finish(slowFails ? _erpDown : null);             // a recarga velha volta (superada) — o `finally` da op 1 roda AGORA
      await rig.pump();
      await rig.add(const ServiceOrderListRequested(status: 'A'));  // troca de aba NO MEIO da op 2
      await rig.finish('list', latest: true);
      final during = rig.lastList().loading;
      final kindBefore = rig.parked(kind);
      await rig.add(_longEvent(kind));                       // op 3 — tem de ser ignorada
      final third = rig.parked(kind) > kindBefore;
      var photo = false;
      if (kind == 'ftransmit') {
        await rig.add(const ServiceOrderFiscalPendingRequested());
        photo = rig.parked('pending') > 0;
      }
      await rig.drain();
      await rig.add(_longEvent(kind));                       // repouso: op 4 toma a trava
      final rest = rig.parked(kind) == 1;
      await rig.drain();
      await rig.close();
      return (during, third, rest, photo);
    }

    for (final kind in _longKinds) {
      for (final slowFails in [false, true]) {
        test('[RESISTIU] PSO-ADV-09 em "$kind" (recarga velha ${slowFails ? 'FALHA' : 'ok'}): o `finally` da execução ANTIGA não solta a '
            'trava da SEGUINTE — a lista no meio dela sai em loading, a 3ª é ignorada${kind == 'ftransmit' ? ', a fotografia não passa' : ''}, '
            'e no repouso a trava toma de novo', () async {
          final (during, third, rest, photo) = await oldFinally(kind, slowFails: slowFails);
          expect([during, third, rest, photo], [true, false, true, false]);
        });
      }
    }

    test('[RESISTIU] duplo/triplo clique no MESMO quadro em cada operação: UMA execução; a 2ª só depois do fim do trabalho da 1ª', () async {
      for (final kind in _longKinds) {
        final rig = _Rig();
        await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await rig.finish('list');
        rig.bloc
          ..add(_longEvent(kind))
          ..add(_longEvent(kind))
          ..add(_longEvent(kind));
        await rig.pump();
        expect(rig.parked(kind), 1, reason: kind);
        await rig.finish(kind);
        await rig.add(_longEvent(kind));   // a trava já soltou (antes da recarga final — D-F169)
        expect(rig.parked(kind), 1, reason: '$kind depois do fim do trabalho');
        await rig.drain();
        await rig.close();
      }
    });

    test('[RESISTIU] exceção NÃO tratada no trabalho (repositório que lança — hoje os repositórios pegam tudo, mas a trava não pode depender '
        'disso): o `finally` solta a trava de cada operação e a próxima toma', () async {
      for (final kind in _longKinds) {
        late _Rig rig;
        final errors = await _guarded(() async {
          rig = _Rig();
          await rig.add(ServiceOrderListRequested(status: kind == 'pending' || kind == 'ftransmit' ? 'F' : 'A', filter: ''));
          await rig.finish('list');
          switch (kind) {
            case 'monthly':
              when(() => rig.repo.monthlyRun(any(), any())).thenThrow(StateError('boom'));
            case 'batch':
              when(() => rig.repo.batchInvoice(any(), any())).thenThrow(StateError('boom'));
            case 'pending':
              when(() => rig.nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenThrow(StateError('boom'));
            default:
              when(() => rig.nfse.transmit(any())).thenThrow(StateError('boom'));
          }
          await rig.add(_longEvent(kind));
        });
        expect(errors.whereType<StateError>(), isNotEmpty, reason: kind);
        // volta o stub normal: a próxima execução tem de tomar a trava
        switch (kind) {
          case 'monthly':
            when(() => rig.repo.monthlyRun(any(), any())).thenAnswer((_) => rig.park('monthly', () => const MonthlyRunReport()));
          case 'batch':
            when(() => rig.repo.batchInvoice(any(), any())).thenAnswer((_) => rig.park('batch', () => BatchInvoiceReport.fromEntries(const [])));
          case 'pending':
            when(() => rig.nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
                .thenAnswer((_) => rig.park('pending', () => const PagedResult<ServiceOrderFiscalPending>.empty()));
          default:
            when(() => rig.nfse.transmit(any())).thenAnswer((_) => rig.park('ftransmit', () => const ServiceOrderTransmitResult(invoiceId: _aId)));
        }
        await rig.add(_longEvent(kind));
        expect(rig.parked(kind), 1, reason: '$kind: trava presa depois da exceção');
        await rig.drain();
        await rig.close();
      }
    });

    test('[RESISTIU] `stopBatches` com o bloc VIVO no meio de cada lote: o lote para sem relatório e sem recarga, a trava solta, e o lote '
        'seguinte (sinal rearmado) roda até o relatório', () async {
      for (final kind in ['batch', 'ftransmit']) {
        final rig = _Rig();
        await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await rig.finish('list');
        await rig.add(_longEvent(kind, fiscalIds: const [_aId, _newId]));
        rig.bloc.stopBatches();
        final callsBefore = rig.listCalls;
        await rig.finish(kind);
        expect([rig.parked(kind), rig.listCalls - callsBefore], [0, 0], reason: '$kind parou depois da unidade em voo');
        expect(rig.states.whereType<ServiceOrderBatchInvoiceDone>().length + rig.states.whereType<ServiceOrderFiscalBatchDone>().length, 0);
        await rig.add(_longEvent(kind));
        expect(rig.parked(kind), 1, reason: '$kind: o lote seguinte toma a trava');
        await rig.drain();
        expect(rig.states.whereType<ServiceOrderBatchInvoiceDone>().length + rig.states.whereType<ServiceOrderFiscalBatchDone>().length, 1);
        expect(rig.lastList().loading, isFalse);
        await rig.close();
      }
    });

    _superseded('[FATO LD-ADV-06] bloc FECHADO no meio: os dois lotes param e não pedem mais nada; a rotina mensal e a fotografia das pendentes '
        'terminam e AINDA pedem a lista ao setes-api depois do close (a recarga final não confere `isClosed` — emissão no-op, GET inútil). '
        'Nenhum erro', () async {
      final after = <String, int>{};
      for (final kind in _longKinds) {
        late _Rig rig;
        final errors = await _guarded(() async {
          rig = _Rig();
          await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));
          await rig.finish('list');
          await rig.add(_longEvent(kind));
          await rig.close();
          await rig.finish(kind);
          await rig.drain();
        });
        expect(errors, isEmpty, reason: kind);
        after[kind] = rig.listCallsAfterClose;
      }
      expect(after, {'monthly': 1, 'batch': 0, 'pending': 1, 'ftransmit': 0});
    });

    test('[DECIDIDO D-F213 — era o FATO LD-ADV-05] a guarda da fotografia é de UM lado só: com a FOTOGRAFIA no ar o lote fiscal (evento direto) começa — as duas '
        'no ar; o fim da fotografia emite as pendentes por cima do lote e o "Transmitir" do diálogo cai na trava SEM aviso. Pela página não '
        'se chega (o lote nasce do diálogo MODAL da fotografia — o I3 da D-F199; o fuzz pela página não achou); o fuzz direto conta o caso',
        () async {
      final rig = _Rig();
      await rig.add(const ServiceOrderListRequested(status: 'F', filter: ''));
      await rig.finish('list');
      await rig.add(const ServiceOrderFiscalPendingRequested());
      await rig.add(const ServiceOrderFiscalTransmitBatchRequested([_aId]));
      final both = [rig.parked('pending'), rig.parked('ftransmit')];
      await rig.finish('pending');
      final pendingOverBatch = rig.states.whereType<ServiceOrderFiscalPendingLoaded>().length;
      await rig.add(const ServiceOrderFiscalTransmitBatchRequested([_aId]));   // o "Transmitir" do diálogo
      final confirmed = rig.parked('ftransmit');
      await rig.drain();
      await rig.close();
      expect([both, pendingOverBatch, confirmed], [
        [1, 1],
        1,
        1,
      ]);
      expect(File(_blocSrc).readAsStringSync(), contains('if (_fiscalBatchLock.held) return;'));
      expect(RegExp(r'_onFiscalTransmitBatchRequested[\s\S]{0,400}_fiscalPendingLock').hasMatch(File(_blocSrc).readAsStringSync()), isFalse);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 2. D-F210 — erro de LEITURA nunca é "rede" nos repositórios do core (ApiClient REAL + MockClient)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('D-F210 × os 10 fallbacks do core', () {
    final calls = <String, Future<Either<Failure, Object?>> Function(ApiClient api)>{
      'login': (api) => AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).login('a@b.c', 'x'),
      'seleção': (api) => AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).selectInstitution('jwt.de.selecao', 1),
      'me': (api) => AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).getMe(),
      'recuperação': (api) => AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).recoveryPassword('a@b.c'),
      'troca de senha': (api) => AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).changePassword('a@b.c', '123', 'nova'),
      'menus': (api) => MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: api)).getMenus(),
      'preferências get': (api) => PreferenceRepositoryImpl(datasource: PreferenceRemoteDatasource(client: api)).getAll(),
      'preferências put': (api) => PreferenceRepositoryImpl(datasource: PreferenceRemoteDatasource(client: api)).save('locale', 'pt'),
      'tema get': (api) => ThemeRepositoryImpl(datasource: ThemeRemoteDatasource(client: api)).getTheme(),
      'tema put': (api) => ThemeRepositoryImpl(datasource: ThemeRemoteDatasource(client: api)).saveTheme(primaryColor: '#000000'),
    };
    const bodies = <String, String>{
      'HTML do proxy': '<html><body>Plesk</body></html>',
      'vazio': '',
      '{}': '{}',
      'array': '[1,2]',
      'null': 'null',
      'ok sem data': '{"ok":true}',
      'data texto': '{"ok":true,"data":"<html>x</html>"}',
      'data lista': '{"ok":true,"data":[1,2]}',
      'tipos trocados': '{"ok":true,"token":5,"data":{"userId":"x","name":1,"primaryColor":7},"select":true,"institutions":"x"}',
      'módulos tortos': '{"ok":true,"data":[{"module":"x","interfaces":3}]}',
    };
    String outcome(Either<Failure, Object?> r) => r.fold(
          (f) => f is NetworkFailure
              ? 'REDE'
              : f.code == ClientFailureCodes.invalidResponse
                  ? 'ilegível'
                  : 'outra ${f.code}',
          (_) => 'ok',
        );

    test('[RESISTIU] 10 chamadas × 10 respostas 200 tortas: NENHUMA vira `NetworkFailure`; o que a leitura não aceita é '
        '`CLIENT_INVALID_RESPONSE` com o texto no ref; e a rede caída (5 exceções do navegador/VM) segue `NetworkFailure` '
        '`core.errors.network` + `NETWORK · setes-api` em TODAS', () async {
      final matrix = <String, String>{};
      for (final MapEntry(key: call, value: run) in calls.entries) {
        for (final MapEntry(key: label, value: body) in bodies.entries) {
          final api = ApiClient(client: MockClient((_) async => http.Response(body, 200)), baseUrl: 'https://api.setes.example');
          final r = await run(api);
          matrix['$call · $label'] = outcome(r);
          r.fold((f) {
            if (f.code == ClientFailureCodes.invalidResponse) expect(f.supportRef, isNotEmpty, reason: '$call · $label');
          }, (_) {});
        }
      }
      expect(matrix.entries.where((e) => e.value == 'REDE' || e.value.startsWith('outra')).toList(), isEmpty);
      final throwers = <Object Function()>[
        () => http.ClientException('Failed to fetch', Uri.parse('https://api.interna.setes.example/auth/login')),
        () => const SocketException('Connection refused'),
        () => TimeoutException('sem resposta'),
        () => StateError('Client is already closed'),
      ];
      var checked = 0;
      for (final boom in throwers) {
        for (final MapEntry(key: call, value: run) in calls.entries) {
          final api = ApiClient(client: MockClient((_) async => throw boom()), baseUrl: 'https://api.setes.example');
          final f = (await run(api)).fold((l) => l, (_) => null);
          final why = '$call · ${boom().runtimeType}';
          expect(f, isA<NetworkFailure>(), reason: why);
          expect([f!.message, f.supportRef], ['core.errors.network', 'NETWORK · setes-api'], reason: why);
          checked++;
        }
      }
      expect(checked, 40);
      // ignore: avoid_print
      print('D-F210 matriz 200 torto: ${matrix.values.fold<Map<String, int>>({}, (m, v) => m..[v] = (m[v] ?? 0) + 1)}');
    });

    test('[FATO LD-ADV-03] o `ApiClient` do setes-api é TOLERANTE (`strictEnvelope: false`) e os leitores do core têm default para tudo: '
        'a página HTML do proxy com 200 (o corpo vira `{}`) é SUCESSO calado em login (sessão sem token), me (usuário 0, sem nome), menus '
        '(menu VAZIO), preferências (nenhuma) e tema (o padrão) — nem rede nem ilegível; só a seleção (`json[\'token\'] as String`) e '
        'tipos trocados chegam ao `invalidResponseFailure` da D-F210', () async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html>Plesk</html>', 200)), baseUrl: 'https://api.setes.example');
      final silent = <String>[
        for (final MapEntry(key: call, value: run) in calls.entries)
          if (outcome(await run(api)) == 'ok') call,
      ];
      // gates do último delta: o LOGIN saiu da lista (LD-ADV-01 corrigido — sem token nem seleção = resposta ilegível); o resto é a
      // questão LD-ADV-03 (os leitores do core conferirem `ok: true`), que aguarda o Valdo
      expect(silent, ['me', 'recuperação', 'troca de senha', 'menus', 'preferências get', 'preferências put', 'tema get', 'tema put']);
      final menus = (await MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: api)).getMenus()).getOrElse(() => throw 'x');
      final me = (await AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).getMe()).getOrElse(() => throw 'x');
      expect([menus.length, me.userId, me.name], [0, 0, '']);
    });

    /// O LOGIN com 200 fora do contrato (`{ ok, token }`): o repositório devolve SUCESSO sem token e o `AuthBloc` faz `session.token!`.
    Future<(List<AuthState>, List<Object>)> loginWith(String body) async {
      final states = <AuthState>[];
      final errors = await _guarded(() async {
        final api = ApiClient(client: MockClient((_) async => http.Response(body, 200)), baseUrl: 'https://api.setes.example');
        final repo = AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api));
        final bloc = AuthBloc(
          loginUsecase: LoginUsecase(repository: repo),
          selectUsecase: SelectInstitutionUsecase(repository: repo),
          recoveryUsecase: RecoveryPasswordUsecase(repository: repo),
          changePasswordUsecase: ChangePasswordUsecase(repository: repo),
          apiClient: api,
          localPrefs: _Prefs(),
        );
        final sub = bloc.stream.listen(states.add);
        bloc.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
        await pumpEventQueue(times: 50);
        await sub.cancel();
        await bloc.close();
      });
      return (states, errors);
    }

    _superseded('[FATO LD-ADV-01] LOGIN com 200 sem token (a página HTML do proxy / host trocado — o corpo vira `{}`; ou `{"ok":true}`): o '
        'repositório devolve SUCESSO com `token: null`, o `AuthBloc` lança `Null check operator` (`session.token!`) DENTRO do handler e o '
        'estado fica `AuthLoading` PARA SEMPRE — o botão "Entrar" gira sem fim, sem diálogo, sem código para o suporte (a D-F210 não '
        'alcança: não há exceção no repositório)', () async {
      for (final body in ['<html>Plesk</html>', '{"ok":true}', '{"ok":true,"select":true}']) {
        final (states, errors) = await loginWith(body);
        expect(states, [isA<AuthLoading>()], reason: body);
        expect(errors.single, isA<TypeError>(), reason: body);
        expect('${errors.single}', contains('Null check operator'), reason: body);
      }
    });

    test('[CORRIGIDO — o datasource do login recusa resposta sem token nem seleção; era o ACHADO LD-ADV-01 MEDIUM] LOGIN com 200 sem token = falha de resposta ilegível (`CLIENT_INVALID_RESPONSE`) → `AuthError` → o '
        'diálogo técnico da tela de login; nunca o spinner preso', () async {
      for (final body in ['<html>Plesk</html>', '{"ok":true}', '{"ok":true,"select":true}']) {
        final (states, errors) = await loginWith(body);
        expect(errors, isEmpty, reason: body);
        expect(states.last, isA<AuthError>().having((s) => s.failure.code, 'code', ClientFailureCodes.invalidResponse), reason: body);
      }
    });

    testWidgets('[FATO LD-ADV-02] o diálogo do LOGIN para a resposta ilegível (seleção de estabelecimento com 200 torto): título "Erro", a '
        'frase do catálogo e a linha "Informe o código … ao suporte" com o TEXTO CRU do Dart (a regra da F2B-ADV-12 — "o texto técnico '
        'fica no supportRef"); no release do web o texto do TypeError é o do dart2js', (tester) async {
      final api = ApiClient(client: MockClient((_) async => http.Response('{"ok":true,"data":"<html>proxy</html>"}', 200)),
          baseUrl: 'https://api.setes.example');
      final f = (await tester.runAsync(() => AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api)).selectInstitution('sel', 1)))!
          .fold((l) => l, (_) => null)!;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => TextButton(onPressed: () => showAuthFailureDialog(context, f), child: const Text('abrir'))),
      ));
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      final texts = _dialogTexts(tester);
      expect(texts, containsAll(['Erro', 'O servidor respondeu num formato inesperado (acione o suporte)']));
      final ref = texts.firstWhere((t) => t.startsWith('Informe o código'));
      expect(ref, contains("type 'Null' is not a subtype of type 'String'"));
      expect(texts.any((t) => t.contains('Sem resposta do serviço')), isFalse);
    });

    test('[RESISTIU] D-F208: a falha de rede escreve o texto cru (serviço, caminho, exceção com a URL) no CONSOLE por `debugPrint` — e só '
        'lá: a `Failure` leva só o código curto', () async {
      final logs = <String?>[];
      final saved = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      try {
        final api = ApiClient(
            client: MockClient((_) async => throw http.ClientException('Failed to fetch', Uri.parse('https://api.interna.setes.example:3000/api/core/menus'))),
            baseUrl: 'https://api.interna.setes.example:3000');
        final f = (await MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: api)).getMenus()).fold((l) => l, (_) => null)!;
        expect([f is NetworkFailure, f.supportRef, '$f'.contains('http')], [true, 'NETWORK · setes-api', false]);
      } finally {
        debugPrint = saved;
      }
      expect(logs.single, allOf(contains('[ApiClient] falha de rede em setes-api /api/core/menus'), contains('Failed to fetch'),
          contains('api.interna.setes.example:3000')));
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 3. D-F209 — `unanchoredFieldsText`
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('D-F209 × unanchoredFieldsText', () {
    test('[RESISTIU] a matriz: 400 de DTO (campo + mensagem — também com a mensagem do campo como chave i18n e com o path raiz `(body)` do '
        'Zod); domínio com a principal CONTENDO / IGUAL / DIFERENTE da do campo; `all` com vários; a principal que é chave i18n', () {
      String t(Failure f, {bool all = false}) => unanchoredFieldsText(f, all: all);
      const dto = Failure(message: 'Validação falhou', statusCode: 400, code: 'VALIDATION_FAILED', fields: [
        FailureField(field: 'dtExpiration', message: 'Data inválida'),
        FailureField(field: 'paymentTypeId', message: 'Obrigatório'),
      ]);
      expect(t(dto), 'Campo "dtExpiration": Data inválida');
      expect(t(dto, all: true), 'Campo "dtExpiration": Data inválida');   // R3: uma pendência por vez (o `all` não vale no DTO)
      expect(
          t(const Failure(message: 'Validação falhou', statusCode: 400, code: 'VALIDATION_FAILED', fields: [FailureField(field: '(body)', message: 'Expected object, received array')])),
          'Campo "(body)": Expected object, received array');
      expect(t(const Failure(message: 'Validação falhou', statusCode: 400, code: 'VALIDATION_FAILED', fields: [FailureField(field: 'x', message: 'core.errors.generic')])),
          'Campo "x": Não foi possível concluir a operação');
      const contains = Failure(message: 'DPS inválido: cTribMun: valor fora do padrão', code: 'FISCAL_DPS_INVALID',
          fields: [FailureField(field: 'dps', message: 'cTribMun: valor fora do padrão')]);
      expect(t(contains), 'DPS inválido: cTribMun: valor fora do padrão');
      const equal = Failure(message: 'Nota não está substituída no fisco', fields: [FailureField(field: 'fiscal', message: 'Nota não está substituída no fisco')]);
      expect(t(equal), 'Nota não está substituída no fisco');
      const different = Failure(message: 'Código municipal fora da forma — corrija a regra de ISS', code: 'FISCAL_DPS_INVALID', fields: [
        FailureField(field: 'municipalCode', message: 'Esperado 3 dígitos'),
        FailureField(field: 'serviceCode', message: 'Esperado 6 dígitos'),
      ]);
      expect(t(different), 'Código municipal fora da forma — corrija a regra de ISS\n• Esperado 3 dígitos');
      expect(t(different, all: true),
          // gates do último delta: no modo `all` a linha é só a mensagem (o `field` é nome técnico)
          'Código municipal fora da forma — corrija a regra de ISS\n• Esperado 3 dígitos\n• Esperado 6 dígitos');
      expect(t(const Failure(message: 'core.errors.generic', fields: [FailureField(field: 'x', message: 'Obrigatório')])),
          'Não foi possível concluir a operação\n• Obrigatório');
    });

    test('[RESISTIU] a forma REAL do `FISCAL_CANCEL_REFUSED` (nfse-api transmission.ts:882 + fiscal-api https-json.ts:259 — `fields` = '
        '`{ field: "event", message: "E0840: …" }` e a principal = "Fisco recusou o cancelamento: " + as mensagens juntas): até 255 '
        'caracteres sai SÓ a principal, que já traz os códigos E (o fixture do gate do passeio tinha `field: "E1235"`, forma que nenhum '
        'produtor monta)', () {
      const f = Failure(message: 'Fisco recusou o cancelamento: E0840: Prazo de cancelamento expirado — E0841: Evento duplicado',
          statusCode: 409, code: 'FISCAL_CANCEL_REFUSED', fields: [
        FailureField(field: 'event', message: 'E0840: Prazo de cancelamento expirado'),
        FailureField(field: 'event', message: 'E0841: Evento duplicado'),
      ]);
      expect(unanchoredFieldsText(f, all: true), f.message);
      expect(unanchoredFieldsText(f, all: true), allOf(contains('E0840'), contains('E0841')));
    });

    _superseded('[FATO LD-ADV-07] o `authorityMessage` da nfse-api CORTA a junção em 255 caracteres: com recusas longas a principal termina no '
        'meio de uma mensagem — essa (e as seguintes) voltam como linha `• event: E0xxx: …` (o nome técnico do campo na frente) e a '
        'cortada aparece DUAS vezes (pela metade na principal, inteira na linha)', () {
      final rejections = [for (var i = 0; i < 4; i++) 'E084$i: ${'Mensagem longa do fisco sobre o evento de cancelamento número $i'.padRight(70, '.')}'];
      final joined = rejections.join(' — ');
      final main = 'Fisco recusou o cancelamento: ${joined.substring(0, 255)}';   // = authorityMessage(...).slice(0, 255)
      final f = Failure(message: main, statusCode: 409, code: 'FISCAL_CANCEL_REFUSED',
          fields: [for (final r in rejections) FailureField(field: 'event', message: r)]);
      final text = unanchoredFieldsText(f, all: true);
      final lines = text.split('\n').skip(1).toList();
      expect(lines, isNotEmpty);
      expect(lines.every((l) => l.startsWith('• event: E084')), isTrue);
      final cut = rejections.firstWhere((r) => !main.contains(r));
      expect(main.contains(cut.substring(0, 10)) && text.contains(cut), isTrue);
    });

    test('[CORRIGIDO — a peça é total; era o ACHADO LD-ADV-08 LOW] a peça da ponte é TOTAL: `fields` vazio devolve a principal (hoje `fields.first` lança `StateError` — os '
        'chamadores atuais guardam com `fields.isNotEmpty`, mas a D-F209 registra "levar a regra à PEÇA da ponte (valendo no app inteiro)")',
        () {
      expect(unanchoredFieldsText(const Failure(message: 'Nota não encontrada', code: 'X')), 'Nota não encontrada');
    });

    _superseded('[FATO LD-ADV-08] `unanchoredFieldsText` com `fields` vazio LANÇA (`fields.first`) — e o ramo do DTO decide só pelo `code`: um '
        '`VALIDATION_FAILED` com principal ESPECÍFICA (o 422 do setes-api modules.service.ts:58 — "Interface(s) não elegível(is) ao menu …" '
        '+ fields com os ids) perde a principal ("Campo "interfaceIds": 12") — hoje fora do alcance (só a página de OS usa a peça)', () {
      expect(() => unanchoredFieldsText(const Failure(message: 'x')), throwsStateError);
      const modules = Failure(message: 'Interface(s) não elegível(is) ao menu (não contratada, não-tela ou do grupo Super): 12', statusCode: 422,
          code: 'VALIDATION_FAILED', fields: [FailureField(field: 'interfaceIds', message: '12')]);
      expect(unanchoredFieldsText(modules), 'Campo "interfaceIds": 12');
      // `FailureField.fromJson` sem `field` (o JSON de um gateway) — nenhum produtor da casa manda (o Zod usa `(body)`)
      expect(unanchoredFieldsText(const Failure(message: 'Validação falhou', code: 'VALIDATION_FAILED', fields: [FailureField(field: '', message: 'x')])),
          'Campo "": x');
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 4. `envelopePage` na lista de OS (ApiClient REAL → datasource → repositório → bloc / página)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('envelopePage × a lista de OS', () {
    Future<List<ServiceOrderState>> listWith(String body, {int status = 200}) async {
      final api = ApiClient(client: MockClient((_) async => http.Response(body, status)), baseUrl: 'https://api.setes.example');
      final bloc = buildServiceOrderBloc(repo: ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api)));
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 30);
      await sub.cancel();
      await bloc.close();
      return states;
    }

    test('[RESISTIU] 200 fora do envelope paginado (HTML, vazio, `{}`, array, `null`, sem `ok`, `ok: false`, `ok: "true"`, `data` objeto/'
        'texto/nulo) → `CLIENT_INVALID_RESPONSE` + `loadFailed` (nunca "nenhum registro"); e o envelope certo com `data: []` segue sendo a '
        'lista vazia legítima', () async {
      const bad = ['<html>proxy</html>', '', '{}', '[]', 'null', '{"data":[]}', '{"ok":false,"data":[]}', '{"ok":"true","data":[]}',
        '{"ok":true,"data":{}}', '{"ok":true,"data":"x"}', '{"ok":true,"data":null}', '{"ok":true}'];
      for (final body in bad) {
        final states = await listWith(body);
        final last = states.whereType<ServiceOrderListState>().last;
        expect([last.loadFailed, last.items.isEmpty, last.loading], [true, true, false], reason: body);
        expect(states.whereType<ServiceOrderActionFailure>().single.failure.code, ClientFailureCodes.invalidResponse, reason: body);
      }
      final empty = await listWith('{"ok":true,"data":[],"page":1,"pageSize":10,"total":0}');
      expect([empty.whereType<ServiceOrderListState>().last.loadFailed, empty.whereType<ServiceOrderActionFailure>().length], [false, 0]);
    });

    _superseded('[FATO LD-ADV-04] o envelope certo com ITENS tortos (`data: [1]`, `customerName` número) passa pelo `envelopePage` e quebra no '
        '`fromJson` — o repositório da OS (o único do módulo que ficou de fora da regra da F2B-ADV-12/D-F210) devolve '
        '`Failure(message: err.toString())`: SEM código, e o TEXTO CRU do Dart vira a MENSAGEM', () async {
      for (final body in ['{"ok":true,"data":[1]}', '{"ok":true,"data":[{"id":1,"customerName":5}]}']) {
        final states = await listWith(body);
        final f = states.whereType<ServiceOrderActionFailure>().single.failure;
        expect([states.whereType<ServiceOrderListState>().last.loadFailed, f.code, f.supportRef], [true, null, null], reason: body);
        expect(f.message, contains('is not a subtype of type'), reason: body);
      }
      expect(File(_osRepoSrc).readAsStringSync(), contains('return Left(Failure(message: err.toString()));'));
    });

    test('[CORRIGIDO — invalidResponseFailure no repositório da OS; era o ACHADO LD-ADV-04 LOW] a resposta que o repositório da OS não lê é `CLIENT_INVALID_RESPONSE` (`invalidResponseFailure` — o molde '
        'dos repositórios nfse/invoice do MESMO módulo), nunca o texto do Dart como mensagem', () async {
      final states = await listWith('{"ok":true,"data":[1]}');
      final f = states.whereType<ServiceOrderActionFailure>().single.failure;
      expect([f.code, f.message], [ClientFailureCodes.invalidResponse, 'core.errors.invalidResponse']);
    });

    testWidgets('[FATO LD-ADV-09] a NATUREZA do diálogo para o MESMO código `CLIENT_INVALID_RESPONSE` depende do caminho: pelo '
        '`envelopePage` (Failure sem ref e sem status) a ponte diz "Atenção" (corrigível pelo usuário) com "… (acione o suporte)" e NENHUM '
        'código; pelo `invalidResponseFailure` é "Erro" com a linha do código. A R7 da ponte (ref, status ≥ 500 ou rede) não conhece os '
        'códigos do cliente', (tester) async {
      final api = ApiClient(client: MockClient((_) async => http.Response('<html>proxy</html>', 200)), baseUrl: 'https://api.setes.example');
      final bloc = buildServiceOrderBloc(repo: ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api)));
      final dispose = await _pumpPage(tester, bloc);
      final texts = _dialogTexts(tester);
      expect(texts, containsAll(['Atenção', 'O servidor respondeu num formato inesperado (acione o suporte)']));
      expect(texts.any((t) => t.startsWith('Informe o código')), isFalse);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect([find.text('Não foi possível carregar a lista.').evaluate().length, find.text('Tentar novamente').evaluate().length,
        find.text('Não encontramos nenhum registro em nossa base.').evaluate().length], [1, 1, 0]);
      await dispose();
    });

    test('[FATO LD-ADV-10] anterior ao delta (o padrão "página esvaziou" das ~28 listas): resposta com `data: []`, `total > 0` e `page > 1` '
        'que NÃO bate com o COUNT (o vetor 5 da skill — COUNT com where diferente da lista) faz o bloc pedir a MESMA página de novo, SEM '
        'limite: `_page = paged.pageCount` (= a própria página) → `_reloadList` → … — aqui 60 GETs seguidos para UM clique na barra (o mock '
        'só para no 61º); com o servidor inconsistente é uma rajada contínua de cada tela aberta', () async {
      final repo = ServiceOrderRepoMock();
      final pages = <int>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        final page = inv.namedArguments[#page] as int;
        pages.add(page);
        if (pages.length == 1) return Right(_listPage([1, 2], total: 30));
        return pages.length <= 61 ? Right(_listPage(const [], page: 3, total: 30)) : Right(_listPage([1], page: 3, total: 21));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(page: 3));
      await pumpEventQueue(times: 2000);
      await bloc.close();
      expect(pages.length, 62);
      expect(pages.skip(1).toSet(), {3});
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 4b. PSO-SOC-04 — `.tr()` nas linhas do relatório do lote de faturamento
  // ---------------------------------------------------------------------------------------------------------------------------------
  testWidgets('[RESISTIU] PSO-SOC-04: o bloco que cai SEM resposta depois de outro já faturado vira linhas "tente de novo" com a frase '
      'NEUTRA traduzida (nunca a chave `core.errors.network`); a recusa do servidor (texto pronto, com `{}` e acento) passa intacta', (tester) async {
    final repo = ServiceOrderRepoMock();
    when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => Right(_listPage([1, 2])));
    var chunk = 0;
    when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments[0] as List<int>;
      if (++chunk == 2) return Left(_erpDown);
      return Right(BatchInvoiceReport.fromEntries([
        for (final id in ids) id == 1 ? const BatchInvoiceEntry(orderId: 1, ok: false, error: 'Sem forma {} de pagamento — ação') : BatchInvoiceEntry(orderId: id, ok: true),
      ]));
    });
    final bloc = buildServiceOrderBloc(repo: repo);
    final dispose = await _pumpPage(tester, bloc);
    bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: [1, for (var i = 2; i <= batchInvoiceChunkSize + 1; i++) 100 + i], input: _input));
    await _settle(tester);
    final texts = _dialogTexts(tester).join(' | ');
    expect(texts, contains('Ordem 7001: Sem forma {} de pagamento — ação'));
    expect(texts, contains('Sem resposta do serviço — rede, proxy ou tempo. — tente de novo'));
    expect(texts, isNot(contains('core.errors')));
    await dispose();
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 5. O estado de falha com page/pageSize e a seleção (PSO-ADV-01/02)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('estado de falha × "Tentar novamente" × seleção', () {
    test('[RESISTIU] o "Tentar novamente" volta à MESMA página e ao MESMO tamanho: página 2 de 25 que falha; troca de tamanho (50) que '
        'falha; a 1ª carga que falha (sem tamanho ainda — o servidor decide); e a falha com uma operação longa no ar sai em loading', () async {
      final rig = _Rig();
      await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await rig.finish('list', failure: _erpDown);                       // 1ª carga falha
      var failed = rig.lastList();
      expect([failed.loadFailed, failed.page, failed.pageSize], [true, 1, null]);
      await rig.add(ServiceOrderListRequested(status: failed.status, filter: failed.filter, page: failed.page, pageSize: failed.pageSize));
      await rig.finish('list');
      await rig.add(const ServiceOrderListRequested(pageSize: 25));
      await rig.finish('list');
      await rig.add(const ServiceOrderListRequested(page: 2));
      await rig.finish('list', failure: _internal);
      failed = rig.lastList();
      expect([failed.loadFailed, failed.page, failed.pageSize, failed.total], [true, 2, 25, null]);
      await rig.add(ServiceOrderListRequested(status: failed.status, filter: failed.filter, page: failed.page, pageSize: failed.pageSize));
      await rig.finish('list');
      await rig.add(const ServiceOrderListRequested(pageSize: 50));
      await rig.finish('list', failure: _erpDown);
      failed = rig.lastList();
      await rig.add(ServiceOrderListRequested(status: failed.status, filter: failed.filter, page: failed.page, pageSize: failed.pageSize));
      await rig.finish('list');
      await rig.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await rig.add(const ServiceOrderListRequested(page: 2));
      await rig.finish('list', failure: _erpDown);
      final underLong = rig.lastList();
      await rig.drain();
      await rig.close();
      expect(rig.listArgs, [(1, null), (1, null), (1, 25), (2, 25), (2, 25), (1, 50), (1, 50), (2, 50), (2, 50)]);
      expect([underLong.loading, underLong.loadFailed, underLong.page], [true, true, 2]);
    });

    /// Marca as OS 1 e 2 na página 1 (total 30, 3 páginas) e pede OUTRA lista (página 2 pela barra, ou outro filtro) que FALHA.
    Future<(int, bool, bool)> markThenFailedChange(WidgetTester tester, ServiceOrderEvent change) async {
      final repo = ServiceOrderRepoMock();
      var n = 0;
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async => ++n == 2 ? Left(_erpDown) : Right(_listPage([1, 2], page: inv.namedArguments[#page] as int, total: 30)));
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await _settle(tester);
      bloc.add(change);
      await _settle(tester);
      await tester.tap(find.text('OK'));   // o diálogo da falha
      await _settle(tester);
      final failedShown = find.text('Não foi possível carregar a lista.').evaluate().length == 1;
      final batchButton = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.receipt_long_outlined), matching: find.byType(IconButton)));
      final badgeFinder = find.ancestor(of: find.byIcon(Icons.receipt_long_outlined), matching: find.byType(Badge));
      final badge = tester.widget<Badge>(badgeFinder);
      final count = badge.isLabelVisible
          ? int.parse(tester.widget<Text>(find.descendant(of: badgeFinder, matching: find.byType(Text)).first).data!)
          : 0;
      await dispose();
      return (count, batchButton.onPressed != null, failedShown);
    }

    _supersededWidgets('[FATO LD-ADV-11] a seleção SOBREVIVE à troca de PÁGINA que falha: a correção do PSO-ADV-02 tirou TODA falha da assinatura '
        '— com a falha da página 2 na tela ("Não foi possível carregar a lista."), o "Faturar selecionadas" fica ARMADO com as 2 OS da '
        'página 1, que o operador não vê. Antes do delta a falha (page 1/pageSize null) trocava a assinatura e limpava a seleção (a regra '
        'da Onda 1: "limpa quando a lista MUDA")', (tester) async {
      final (count, armed, failedShown) = await markThenFailedChange(tester, const ServiceOrderListRequested(page: 2));
      expect([count, armed, failedShown], [2, true, true]);
      expect(File(_pageSrc).readAsStringSync(), contains('if (!state.loading && !state.loadFailed) {'));
    });

    _supersededWidgets('[FATO LD-ADV-11] idem pelo FILTRO que falha (o caso da Onda 1: "marcar 12 na página 1, filtrar por outro cliente e '
        'clicar em Faturar selecionadas faturava ordens que o operador não estava mais vendo")', (tester) async {
      final (count, armed, failedShown) = await markThenFailedChange(tester, const ServiceOrderListRequested(filter: 'outro cliente'));
      expect([count, armed, failedShown], [2, true, true]);
    });

    testWidgets('[CORRIGIDO — a falha entra na assinatura da seleção; era o ACHADO LD-ADV-11 LOW] a falha de uma lista DIFERENTE (outra página/filtro/critério) limpa a seleção; só a falha da MESMA '
        'lista (a recarga do fim do lote — PSO-ADV-02) a mantém. Com page/pageSize no estado de falha a assinatura já distingue as duas',
        (tester) async {
      final (count, armed, _) = await markThenFailedChange(tester, const ServiceOrderListRequested(page: 2));
      expect([count, armed], [0, false]);
    });

    test('[RESISTIU] PSO-ADV-02 + a assinatura: a falha da recarga do FIM do lote tem a MESMA assinatura da lista carregada antes '
        '(status/página/tamanho/filtro/critérios) — incluir a falha na assinatura manteria a seleção das recusadas (a correção do '
        'LD-ADV-11 não reabre o PSO-ADV-02)', () async {
      final rig = _Rig();
      await rig.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await rig.finish('list');
      final loaded = rig.lastList();
      await rig.add(const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input));
      await rig.finish('batch');
      await rig.finish('list', failure: _erpDown);
      final failed = rig.lastList();
      await rig.close();
      String sig(ServiceOrderListState s) => '${s.status}|${s.page}|${s.pageSize}|${s.filter}|${s.criteria.toQueryJson()}';
      expect(failed.loadFailed, isTrue);
      expect(sig(failed), sig(loaded));
    });
  });
}
