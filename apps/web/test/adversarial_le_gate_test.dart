// GATE ADVERSARIAL independente do delta `60df1df..5f6d3be` da F2b (setes-app, branch f2b — commits d08ac1b "Gates do último delta
// (f312f06..60df1df): login sem token, código E do fisco, D-F213" e 5f6d3be "D-F214…D-F217: falha do cliente técnica, console sem query,
// leitores do core no envelope, recuo de página"):
//   - core: o login recusa 200 sem token/seleção (LD-ADV-01); `invalidResponseFailure(e, {service})` com o código curto
//     `INVALID_RESPONSE · <serviço>` + `debugPrint` (D-F216); `envelopeOk` em TODAS as chamadas de auth/menu/preferência/tema (D-F216);
//     `isTechnicalFailure` com `ClientFailureCodes.all` (D-F214); o console da falha de rede sem a query e sem o `uri=` (D-F215);
//   - app: `feedback.dart` técnico para `ClientFailureCodes.all` (D-F214); `unanchoredFieldsText` total / DTO só no 400 / linhas sem nome
//     no `all`; repositórios da OS com o serviço; bloc da OS: `isClosed` antes da recarga final (rotina mensal, fotografia — LD-ADV-06),
//     recuo de página só se `page > pageCount` (D-F217); seleção com `!state.loading` (LD-ADV-11).
//
// O que o delta PROMETE e este gate ataca: (1) o LOGIN inteiro (AuthBloc + ApiClient REAIS sobre o MockClient do package:http) nunca
// deixa spinner preso, nunca mostra texto cru e escolhe o diálogo certo (técnico × validação) — inclusive token vazio, seleção sem lista,
// recuperação/troca de senha com corpo vazio e o 401 de negócio; (2) `envelopeOk` não quebra NENHUMA rota real (as formas de resposta
// copiadas de setes-api-f2a/src/modules/auth/auth.routes.ts e core/core.routes.ts — SÓ LEITURA — e uma cerca que relê os dois arquivos);
// (3) a natureza dos diálogos dos 3 códigos do cliente nas DUAS pontes, sem mexer no 401 global (D-F138) nem na confirmação do emissor
// (D-F148); (4) D-F217 por fuzz (300 sementes × 3 servidores) e sequências dirigidas: o recuo legítimo (a última página esvaziou depois
// de faturar/cancelar) segue recuando, o servidor com COUNT incoerente não entra em laço, página 1 vazia, `pageSize` ausente; (5) o
// `isClosed` antes da recarga final (rotina mensal e fotografia, ok/falha, bloc fechado antes do trabalho voltar e durante a recarga
// final); (6) seleção × falha pela PÁGINA de verdade (a recarga do fim do lote que falha mantém as recusadas; outra página/tamanho/
// critério que falha limpa).
//
// Convenção do gate (a mesma dos gates R5–R16, do passeio e do LD):
//   - `[ACHADO LE-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — fica com `skip:` para a suíte seguir verde. Para
//     ver a falha:   flutter test --run-skipped test/adversarial_le_gate_test.dart
//   - `[FATO LE-ADV-NN]` = o comportamento atual registrado (roda sempre) — a PROVA executável de hoje de cada achado/limite.
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail; o `ApiClient`/`NfseApiClient` DE VERDADE sobre o `MockClient`; a página de OS e as
// telas de auth montadas de verdade. A cerca das rotas do setes-api só LÊ os arquivos (SETES_API_DIR ou ../../../setes-api-f2a).
//
// RESULTADO (2026-10-14): sem HIGH/CRITICAL; nenhum MEDIUM. RESISTIRAM: o login nas 21 formas de resposta (nenhum spinner preso, nenhum
// erro não tratado, técnico × validação certos, o 401 de negócio nunca expira a sessão), as 10 leituras do core contra as formas REAIS
// das rotas + a cerca das rotas (todo 2xx de auth.routes.ts/core.routes.ts é `{ ok: true, … }`), a matriz de 13 falhas nas duas pontes
// (D-F214 — inclusive o código de SERVIDOR que começa com `CLIENT_`), o 401 global e a confirmação do emissor (4 respostas do `/me`), o
// fuzz da D-F217 (consistente, COUNT incoerente, sem `pageSize`: ≤ 2 GETs por ação, recuo legítimo exercitado), o recuo legítimo pelo
// lote e pelo "Cancelar OS", o `isClosed` (8 combinações + o controle sem fechar) e a seleção pela página (E2E das recusadas com a
// recarga que falha + "Tentar novamente"; tamanho e critério que falham limpam). ACHADOS (todos LOW): LE-ADV-01 (token vazio = login
// "bem-sucedido" sem sessão), LE-ADV-02 (token que a guarda recusa — relógio do dispositivo adiantado além do `exp`, não-JWT — volta ao
// login CALADO), LE-ADV-03 (seleção com a lista vazia = tela sem saída), LE-ADV-04 (D-F216 pela metade: o envelope ilegível pelo
// `envelopeData`/`envelopePage`/envelope estrito do `_send` sai SEM o código curto — o caso típico do Plesk na NFSE_API_URL), LE-ADV-05
// (a guarda da D-F217 lê a página da RESPOSTA: resposta que não segue a página pedida volta ao laço), LE-ADV-06 (o ramo
// `FISCAL_DPS_REJECTED` da página ainda põe o nome técnico `dps:` antes do código E), LE-ADV-07 (D-F215: o regex tira só o `uri=` — uma
// causa que EMBUTE a URL leva a query ao console; o próprio navegador registra a URL das falhas).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
// ignore: implementation_imports
import 'package:core/src/auth/presentation/content/auth_feedback.dart';
// ignore: implementation_imports
import 'package:core/src/auth/presentation/content/login_form.dart';
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
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/page/service_order_page.dart';
import 'package:setes_web/app/shared/feedback/feedback.dart';
import 'package:setes_web/app/shared/search/search_criteria_datasource.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_widgets/setes_widgets.dart';

import 'support/service_order_bloc_factory.dart';

const _blocSrc = 'lib/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';
const _appFeedbackSrc = 'lib/app/shared/feedback/feedback.dart';
const _coreFeedbackSrc = '../../packages/core/lib/src/auth/presentation/content/auth_feedback.dart';
const _apiClientSrc = '../../packages/core/lib/src/shared/http/api_client.dart';
const _guardSrc = '../../packages/core/lib/src/auth/presentation/guard/setes_auth_guard.dart';

const _base = 'https://api.setes.example';
const _nfseBase = 'https://nfse.setes.example';
const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
const _invalid = ClientFailureCodes.invalidResponse;
const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

final _erpDown = NetworkFailure(detail: networkFailureCode('setes-api'));

http.Response _r(String body, [int status = 200]) => http.Response(body, status, headers: _jsonHeaders);

/// JWT de teste (o app nunca confere a assinatura — `isJwtExpired` só lê o `exp`).
String _jwt({int? exp}) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'RS256', 'kid': 'k1'})}.${seg({'sub': 1, if (exp != null) 'exp': exp})}.assinatura';
}

int _epoch(Duration d) => DateTime.now().add(d).millisecondsSinceEpoch ~/ 1000;

const _institutions = '[{"institutionId":1,"schemaName":"setes_a","name":"Empresa A","profile":"admin"},'
    '{"institutionId":2,"schemaName":"setes_b","name":"Empresa B","profile":"regular"}]';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

PagedResult<ServiceOrderListItem> _listPage(List<int> ids, {int page = 1, int pageSize = 10, int? total}) => PagedResult(items: [
      for (final id in ids) ServiceOrderListItem(id: id, number: 7000 + id, customerId: id, customerName: 'Cliente $id', status: 'A'),
    ], page: page, pageSize: pageSize, total: total ?? ids.length);

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

// =====================================================================================================================================
// Rig do LOGIN: AuthBloc + ApiClient REAIS; o MockClient responde por CAMINHO
// =====================================================================================================================================

class _Prefs extends LocalPrefs {
  String? saved;
  bool keep = false;
  @override
  Future<bool> getKeepConnected() async => keep;
  @override
  Future<void> setKeepConnected(bool value) async => keep = value;
  @override
  Future<String?> getSessionToken() async => saved;
  @override
  Future<void> setSessionToken(String? token) async => saved = token;
  @override
  Future<String?> getRememberedEmail() async => null;
  @override
  Future<void> setRememberedEmail(String? email) async {}
  @override
  Future<int?> getDefaultInstitutionId() async => null;
  @override
  Future<void> setDefaultInstitutionId(int? institutionId) async {}
}

typedef _Route = Future<http.Response> Function(http.Request req);

class _AuthRig {
  _AuthRig(Map<String, _Route> routes, {String? sessionBefore}) {
    if (sessionBefore != null) session.value = sessionBefore;
    session.addExpiredListener(() => expired++);
    api = ApiClient(
      client: MockClient((req) async {
        requests.add(req);
        final route = routes[req.url.path];
        return route == null ? _r('{"error":"rota inexistente no rig"}', 404) : route(req);
      }),
      baseUrl: _base,
      session: session,
    );
    final repo = AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api));
    bloc = AuthBloc(
      loginUsecase: LoginUsecase(repository: repo),
      selectUsecase: SelectInstitutionUsecase(repository: repo),
      recoveryUsecase: RecoveryPasswordUsecase(repository: repo),
      changePasswordUsecase: ChangePasswordUsecase(repository: repo),
      apiClient: api,
      localPrefs: prefs,
    );
    sub = bloc.stream.listen(states.add);
  }

  final session = ProductToken();
  final prefs = _Prefs();
  late final ApiClient api;
  late final AuthBloc bloc;
  late final StreamSubscription<AuthState> sub;
  final states = <AuthState>[];
  final requests = <http.Request>[];
  var expired = 0;

  Future<void> add(AuthEvent e) async {
    bloc.add(e);
    await pumpEventQueue(times: 60);
  }

  Future<void> close() async {
    await sub.cancel();
    await bloc.close();
  }
}

_Route _ok(String body, [int status = 200]) => (_) async => _r(body, status);

/// O desfecho legível de um passo do workflow: o estado final e, na falha, código / ref / natureza.
String _describe(AuthState s) => switch (s) {
      AuthAuthenticated() => 'autenticado',
      AuthNeedsSelection(:final session) => 'seleção(${session.institutions.length})',
      AuthRecoveryEmailSent() => 'código enviado',
      AuthPasswordChanged() => 'senha alterada',
      AuthLoading() => 'SPINNER',
      AuthError(:final failure) => 'erro ${isTechnicalFailure(failure) ? 'técnico' : 'validação'} '
          '${failure.runtimeType}/${failure.code}/${failure.supportRef}',
      _ => '$s',
    };

// =====================================================================================================================================
// Página de OS de verdade (molde dos gates do passeio/LD)
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

class _GuardModule extends Module {
  _GuardModule(this.api, this.prefs);
  final ApiClient api;
  final LocalPrefs prefs;

  @override
  List<Bind> get binds => [Bind.instance<ApiClient>(api), Bind.instance<LocalPrefs>(prefs)];
}

Future<Future<void> Function()> _pumpPage(WidgetTester tester, ServiceOrderBloc bloc) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  final search = _SearchDsMock();
  when(() => search.criteria()).thenAnswer((_) async => const <SearchCriterion>[]);
  Modular.init(_PageModule(bloc, _OsDsMock(), search));
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

/// O contador do "Faturar selecionadas" e se o botão está armado.
(int, bool) _batchBadge(WidgetTester tester) {
  final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.receipt_long_outlined), matching: find.byType(IconButton)));
  final badgeFinder = find.ancestor(of: find.byIcon(Icons.receipt_long_outlined), matching: find.byType(Badge));
  final badge = tester.widget<Badge>(badgeFinder);
  final count = badge.isLabelVisible
      ? int.parse(tester.widget<Text>(find.descendant(of: badgeFinder, matching: find.byType(Text)).first).data!)
      : 0;
  return (count, button.onPressed != null);
}

// =====================================================================================================================================
// Servidor da lista paginada (D-F217): COUNT, eco da página e `pageSize` controlados
// =====================================================================================================================================

class _ListServer {
  _ListServer({required this.rows, this.countDelta = 0, this.sendPageSize = true, this.defaultSize = 10});
  int rows;
  final int countDelta;
  final bool sendPageSize;
  final int defaultSize;
  final pages = <int>[];

  /// A forma do setes-api (`pagedEnvelope`): ecoa a página pedida, `pageSize` inválido cai no default; `total` = COUNT (+ incoerência).
  PagedResult<ServiceOrderListItem> answer(int page, int? size) {
    pages.add(page);
    final s = size == null || size <= 0 ? defaultSize : size;
    final start = (page - 1) * s;
    final n = max(0, min(s, rows - start));
    final items = [
      for (var i = 0; i < n; i++)
        ServiceOrderListItem(id: start + i + 1, number: 7000 + start + i + 1, customerId: 1, customerName: 'C', status: 'A'),
    ];
    // sem `pageSize` no corpo o `PagedResult.fromJson` usa `data.length`
    return PagedResult(items: items, page: page, pageSize: sendPageSize ? s : items.length, total: max(0, rows + countDelta));
  }
}

class _FuzzOut {
  final violations = <String>[];
  final counts = <String, int>{};
  void count(String k) => counts[k] = (counts[k] ?? 0) + 1;
}

Future<void> _pageFuzz(int seed, String mode, _FuzzOut out) async {
  final rnd = Random(seed);
  final server = _ListServer(
    rows: rnd.nextInt(70),
    countDelta: mode == 'COUNT incoerente' ? rnd.nextInt(25) - 12 : 0,
    sendPageSize: mode != 'sem pageSize',
    defaultSize: const [10, 25][rnd.nextInt(2)],
  );
  final repo = ServiceOrderRepoMock();
  when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
      .thenAnswer((inv) async => Right(server.answer(inv.namedArguments[#page] as int, inv.namedArguments[#pageSize] as int?)));
  final bloc = buildServiceOrderBloc(repo: repo);
  final states = <ServiceOrderState>[];
  final sub = bloc.stream.listen(states.add);
  bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
  await pumpEventQueue(times: 40);
  for (var step = 0; step < 25; step++) {
    final shown = states.whereType<ServiceOrderListState>().last;
    final shownCount = PagedResult<int>(items: const [], page: 1, pageSize: shown.pageSize ?? 10, total: shown.total ?? 0).pageCount;
    final ServiceOrderEvent e;
    final String what;
    switch (rnd.nextInt(7)) {
      case 0:
      case 1:
        final p = 1 + rnd.nextInt(shownCount + 1);   // a barra mostra 1..pageCount; +1 = a barra velha de antes de outra operação
        e = ServiceOrderListRequested(page: p);
        what = 'página $p';
      case 2:
        server.rows = max(0, server.rows - 1 - rnd.nextInt(15));   // faturar/cancelar tirou OS da aba
        e = ServiceOrderListRequested(page: shown.page);
        what = 'operação tirou OS (rows ${server.rows}) e recarregou a página ${shown.page}';
      case 3:
        server.rows += rnd.nextInt(15);
        e = const ServiceOrderBackToListPressed();
        what = 'OS novas (rows ${server.rows}) + voltar à lista';
      case 4:
        final size = const [10, 25, 50][rnd.nextInt(3)];
        e = ServiceOrderListRequested(pageSize: size);
        what = 'tamanho $size';
      default:
        server.rows = max(0, server.rows - rnd.nextInt(30));
        e = const ServiceOrderBackToListPressed();
        what = 'lote tirou OS (rows ${server.rows}) + recarga';
    }
    final before = server.pages.length;
    bloc.add(e);
    await pumpEventQueue(times: 60);
    final gets = server.pages.length - before;
    final last = states.whereType<ServiceOrderListState>().last;
    String why(String o) => '$mode semente $seed passo $step ($what): $o — GETs ${server.pages.sublist(before)}';
    if (gets > 2) out.violations.add(why('(O1) $gets GETs para UMA ação'));
    if (gets == 2) out.count('$mode: recuo');
    if (last.loading) out.violations.add(why('(O2) spinner preso'));
    if (mode == 'consistente') {
      final size = last.pageSize ?? 10;
      final lastPage = server.rows == 0 ? 1 : (server.rows + size - 1) ~/ size;
      if (server.rows > 0 && (last.page > lastPage || last.items.isEmpty)) {
        out.violations.add(why('(O3) página ${last.page} de $lastPage com ${last.items.length} itens (rows ${server.rows})'));
      }
    }
  }
  await sub.cancel();
  await bloc.close();
}

// =====================================================================================================================================
// Rig das operações longas com resposta ESTACIONADA (o `isClosed` da rotina mensal e da fotografia)
// =====================================================================================================================================

class _Flight {
  _Flight(this.kind, this.finish);
  final String kind;
  final void Function(Failure? failure) finish;
}

class _Park {
  _Park() {
    when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) {
      listCalls++;
      if (closed) listCallsAfterClose++;
      return park('list', () => _listPage([1, 2]));
    });
    when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
    when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) => park('pending',
        () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: 9, number: '9001')], page: 1, pageSize: 100, total: 1)));
    bloc = buildServiceOrderBloc(repo: repo, nfse: nfse);
    sub = bloc.stream.listen(states.add);
  }

  final repo = ServiceOrderRepoMock();
  final nfse = NfseRepoMock();
  late final ServiceOrderBloc bloc;
  late final StreamSubscription<ServiceOrderState> sub;
  final flights = <_Flight>[];
  final states = <ServiceOrderState>[];
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

  Future<void> finish(String kind, {Failure? failure}) async {
    final f = flights.firstWhere((f) => f.kind == kind);
    flights.remove(f);
    f.finish(failure);
    await pump();
  }

  Future<void> drain() async {
    for (var i = 0; i < 50 && flights.isNotEmpty; i++) {
      flights.removeAt(0).finish(null);
      await pump();
    }
  }

  Future<void> close() async {
    closed = true;
    await sub.cancel();
    await bloc.close();
  }
}

ServiceOrderEvent _longEvent(String kind) =>
    kind == 'monthly' ? const ServiceOrderMonthlyRunRequested(year: 2026, month: 10) : const ServiceOrderFiscalPendingRequested();

/// As PROVAS de antes das correções/decisões da sessão (gates do delta 60df1df..5f6d3be, 2026-10-14): o comportamento que cada FATO
/// registrava não existe mais; ficam PULADAS como histórico — o [CORRIGIDO]/[DECIDIDO] de cada achado prova o novo.
const _supersededReason = 'prova de ANTES da correção da sessão (gates do delta 60df1df..5f6d3be) — o [CORRIGIDO]/[DECIDIDO] prova o novo';
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
  // 1. O LOGIN inteiro — AuthBloc + ApiClient REAIS + MockClient
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(1) o fluxo de login', () {
    final jwt = _jwt(exp: _epoch(const Duration(hours: 12)));
    final jwt2 = _jwt(exp: _epoch(const Duration(hours: 20)));

    test('[RESISTIU] a matriz do LOGIN (21 formas de resposta do POST /auth/login): só o contrato da rota (`{ok, token, context}` / '
        '`{ok, select, selectionToken, institutions}`) entra; tudo o mais é falha com o diálogo certo — e NUNCA o spinner preso nem '
        'erro não tratado; o 401 de negócio não expira a sessão que já estava no ProductToken', () async {
      final cases = <String, (_Route, String)>{
        'token válido (a forma REAL)': (_ok('{"ok":true,"token":"$jwt","context":{"isSalesman":false}}'), 'autenticado'),
        'seleção (a forma REAL)': (_ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":$_institutions}'), 'seleção(2)'),
        'sem `ok`': (_ok('{"token":"$jwt"}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '`ok: false` com 200': (_ok('{"ok":false,"token":"$jwt"}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '`ok: "true"` (texto)': (_ok('{"ok":"true","token":"$jwt"}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'HTML do proxy': (_ok('<html><body>Plesk</body></html>'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'corpo vazio': (_ok(''), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'array': (_ok('[1,2]'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '`{ok:true}` sem token nem seleção': (_ok('{"ok":true}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'seleção sem selectionToken': (_ok('{"ok":true,"select":true,"institutions":$_institutions}'),
            'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'token número': (_ok('{"ok":true,"token":5}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'institutions texto': (_ok('{"ok":true,"select":true,"selectionToken":"s","institutions":"x"}'),
            'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'institution com id texto': (_ok('{"ok":true,"select":true,"selectionToken":"s","institutions":[{"institutionId":"1"}]}'),
            'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '401 senha errada (a forma REAL)': (_ok('{"error":"Email ou senha inválidos"}', 401), 'erro validação UnauthorizedFailure/null/null'),
        '401 usuário inativo': (_ok('{"error":"Usuário inativo"}', 401), 'erro validação UnauthorizedFailure/null/null'),
        '403 sem institution ativa': (_ok('{"error":"Usuário sem institution ativa"}', 403), 'erro validação Failure/null/null'),
        '400 campos obrigatórios': (_ok('{"error":"Os campos \\"email\\" e \\"password\\" são obrigatórios"}', 400),
            'erro validação Failure/null/null'),
        '429 do rate limit': (_ok('{"error":"Limite de requisições excedido. Tente novamente em 1 minuto."}', 429),
            'erro validação Failure/null/null'),
        '500 (a forma REAL)': (_ok('{"error":"Erro interno"}', 500), 'erro técnico Failure/null/null'),
        '502 HTML do proxy': (_ok('<html>Bad Gateway</html>', 502), 'erro técnico Failure/null/null'),
        'rede caída': ((_) async => throw http.ClientException('Failed to fetch', Uri.parse('$_base/auth/login')),
            'erro técnico NetworkFailure/null/NETWORK · setes-api'),
      };
      final got = <String, String>{};
      for (final MapEntry(key: name, value: (route, _)) in cases.entries) {
        late _AuthRig rig;
        final errors = await _guarded(() async {
          rig = _AuthRig({'/auth/login': route}, sessionBefore: 'sessao-velha');
          await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
          await rig.close();
        });
        expect(errors, isEmpty, reason: name);
        expect(rig.states.first, isA<AuthLoading>(), reason: name);
        got[name] = _describe(rig.states.last);
        // o login é rota PÚBLICA: nunca leva o Bearer da sessão e o 401 dele nunca expira a sessão
        expect([rig.requests.single.headers['Authorization'], rig.expired], [null, 0], reason: name);
        if (got[name]!.startsWith('erro')) expect(rig.session.value, 'sessao-velha', reason: name);
      }
      expect(got, {for (final MapEntry(key: n, value: (_, want)) in cases.entries) n: want});
    });

    test('[RESISTIU] seleção → JWT final: o select-institution leva o `selectionToken` (nunca a sessão), a forma REAL entra; `{ok:true}` '
        'sem token, HTML, `ok:false` e o 401 do token de seleção vencido são falhas com o diálogo certo — sem spinner preso', () async {
      final cases = <String, (_Route, String)>{
        'a forma REAL': (_ok('{"ok":true,"token":"$jwt2","context":{}}'), 'autenticado'),
        '`{ok:true}` sem token': (_ok('{"ok":true}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'HTML': (_ok('<html>x</html>'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '`ok:false`': (_ok('{"ok":false,"token":"$jwt2"}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '401 seleção vencida (a forma REAL)': (_ok('{"error":"Token de seleção inválido ou expirado"}', 401),
            'erro validação UnauthorizedFailure/null/null'),
        '403 sem vínculo': (_ok('{"error":"Usuário sem vínculo ativo com esta institution"}', 403), 'erro validação Failure/null/null'),
      };
      for (final MapEntry(key: name, value: (route, want)) in cases.entries) {
        late _AuthRig rig;
        final errors = await _guarded(() async {
          rig = _AuthRig({
            '/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":$_institutions}'),
            '/auth/select-institution': route,
          });
          await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
          await rig.add(const AuthInstitutionSelected(institutionId: 2, setAsDefault: false));
          await rig.close();
        });
        expect(errors, isEmpty, reason: name);
        expect(_describe(rig.states.last), want, reason: name);
        expect(rig.requests.last.headers['Authorization'], 'Bearer sel', reason: name);
        expect(rig.expired, 0, reason: name);
        if (want == 'autenticado') expect([rig.api.token, (rig.states.last as AuthAuthenticated).token], [jwt2, jwt2]);
      }
    });

    test('[RESISTIU] recuperação e troca de senha: a forma REAL (`{ok:true, message}` / `{ok:true}`) entra; 200 com corpo VAZIO (o proxy) '
        'e HTML viram falha técnica com o código curto; o 401 do código vencido e o 400 são de validação — nunca spinner preso', () async {
      final recovery = <String, (_Route, String)>{
        'a forma REAL': (_ok('{"ok":true,"message":"Se o email existir, um código de recuperação foi enviado"}'), 'código enviado'),
        '`{ok:true}`': (_ok('{"ok":true}'), 'código enviado'),
        'corpo vazio': (_ok(''), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        'HTML': (_ok('<html>x</html>'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '400': (_ok('{"error":"O campo \\"email\\" é obrigatório"}', 400), 'erro validação Failure/null/null'),
      };
      final change = <String, (_Route, String)>{
        'a forma REAL': (_ok('{"ok":true}'), 'senha alterada'),
        'corpo vazio': (_ok(''), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '`ok:false`': (_ok('{"ok":false}'), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api'),
        '401 código vencido (a forma REAL)': (_ok('{"error":"Código inválido ou expirado"}', 401), 'erro validação UnauthorizedFailure/null/null'),
        '400 senha curta (a forma REAL)': (_ok('{"error":"A nova senha deve ter pelo menos 5 caracteres"}', 400), 'erro validação Failure/null/null'),
      };
      for (final MapEntry(key: name, value: (route, want)) in recovery.entries) {
        late _AuthRig rig;
        final errors = await _guarded(() async {
          rig = _AuthRig({'/auth/recovery-password': route}, sessionBefore: 'viva');
          await rig.add(const AuthRecoveryRequested(email: 'a@b.c'));
          await rig.close();
        });
        expect([errors, _describe(rig.states.last), rig.expired, rig.session.value], [isEmpty, want, 0, 'viva'], reason: 'recuperação $name');
      }
      for (final MapEntry(key: name, value: (route, want)) in change.entries) {
        late _AuthRig rig;
        final errors = await _guarded(() async {
          rig = _AuthRig({'/auth/change-password': route}, sessionBefore: 'viva');
          await rig.add(const AuthChangePasswordRequested(code: '123456', newPassword: 'nova123', email: 'a@b.c'));
          await rig.close();
        });
        expect([errors, _describe(rig.states.last), rig.expired, rig.session.value], [isEmpty, want, 0, 'viva'], reason: 'troca $name');
      }
    });

    testWidgets('[RESISTIU] a TELA de login (LoginForm real): 200 ilegível → diálogo "Erro" com a frase do catálogo e "Informe o código '
        'INVALID_RESPONSE · setes-api ao suporte" (nada do Dart, nada do HTML); 401 de negócio → texto inline, sem diálogo; rede → "Erro" '
        'com NETWORK · setes-api; e o botão nunca fica girando', (tester) async {
      Future<(List<String>, bool, bool)> submit(_Route route, String inline) async {
        final rig = _AuthRig({'/auth/login': route});
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LoginForm(bloc: rig.bloc)))));
        await _settle(tester);
        await tester.enterText(find.byType(TextField).at(0), 'a@b.c');
        await tester.enterText(find.byType(TextField).at(1), 'segredo');
        await tester.tap(find.text('ENTRAR'));
        await _settle(tester);
        final texts = _dialogTexts(tester);
        final spinning = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        final inlineShown = find.text(inline).evaluate().isNotEmpty;
        if (find.text('OK').evaluate().isNotEmpty) {
          await tester.tap(find.text('OK'));
          await _settle(tester);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(rig.close);
        return (texts, spinning, inlineShown);
      }

      final (html, htmlSpin, _) = await submit(_ok('<html><body>Plesk</body></html>'), '-');
      expect(html, containsAll(['Erro', 'O servidor respondeu num formato inesperado (acione o suporte)',
        'Informe o código INVALID_RESPONSE · setes-api ao suporte']));
      expect(html.where((t) => t.contains('<html') || t.contains('subtype') || t.contains('Null') || t.contains('envelope')), isEmpty);
      expect(htmlSpin, isFalse);
      final (wrong, wrongSpin, wrongInline) = await submit(_ok('{"error":"Email ou senha inválidos"}', 401), 'Email ou senha inválidos');
      expect([wrong, wrongSpin, wrongInline], [isEmpty, false, true]);
      final (down, downSpin, _) = await submit((_) async => throw http.ClientException('Failed to fetch', Uri.parse('$_base/auth/login')), '-');
      expect(down, containsAll(['Erro', 'Sem resposta do serviço — rede, proxy ou tempo.', 'Informe o código NETWORK · setes-api ao suporte']));
      expect(downSpin, isFalse);
    });

    // --- LE-ADV-01 — token vazio ---------------------------------------------------------------------------------------------------
    _superseded('[FATO LE-ADV-01] LOGIN com `{"ok":true,"token":""}`: a guarda do LD-ADV-01 confere só `null` — o `AuthBloc` emite '
        '`AuthAuthenticated(token: "")`, mas o `ProductToken` grava vazio como NULO (sem sessão): a tela vai para /home/ e a guarda '
        'devolve ao login sem nenhuma palavra. Idem `selectionToken: ""`: a seleção abre e o select-institution sai com `Bearer ` vazio',
        () async {
      final rig = _AuthRig({'/auth/login': _ok('{"ok":true,"token":"","context":{}}')});
      await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      await rig.close();
      expect([rig.states.last is AuthAuthenticated, (rig.states.last as AuthAuthenticated).token, rig.api.token, isJwtExpired('')],
          [true, '', null, true]);
      final sel = _AuthRig({
        '/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"","institutions":$_institutions}'),
        '/auth/select-institution': _ok('{"error":"Token de seleção inválido ou expirado"}', 401),
      });
      await sel.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      final needs = _describe(sel.states.last);
      await sel.add(const AuthInstitutionSelected(institutionId: 1, setAsDefault: false));
      await sel.close();
      expect([needs, sel.requests.last.headers['Authorization'], _describe(sel.states.last)],
          ['seleção(2)', 'Bearer ', 'erro validação UnauthorizedFailure/null/null']);
    });

    test('[CORRIGIDO — token vazio = ausente; era o ACHADO LE-ADV-01 LOW] token (ou token de seleção) VAZIO é a mesma "resposta sem token" do LD-ADV-01: falha técnica '
        '`CLIENT_INVALID_RESPONSE` com o código curto, nunca "autenticado" sem sessão', () async {
      for (final body in ['{"ok":true,"token":"","context":{}}', '{"ok":true,"select":true,"selectionToken":"","institutions":$_institutions}']) {
        final rig = _AuthRig({'/auth/login': _ok(body)});
        await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
        await rig.close();
        expect(_describe(rig.states.last), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api', reason: body);
      }
    });

    // --- LE-ADV-02 — token que a guarda recusa ----------------------------------------------------------------------------------
    _supersededWidgets('[FATO LE-ADV-02] token que a GUARDA recusa (o relógio do dispositivo adiantado além do `exp` — o JWT já "vencido" pelo '
        'relógio local —, ou um token não-JWT): o login é "bem-sucedido", a `SetesAuthGuard` recusa /home/ e redireciona a /login — e a '
        'tela de login fica MUDA (sem diálogo, sem texto, botão livre): o operador clica de novo e o ciclo se repete sem pista',
        (tester) async {
      for (final token in [_jwt(exp: _epoch(const Duration(hours: -1))), 'nao-e-um-jwt']) {
        final rig = _AuthRig({'/auth/login': _ok('{"ok":true,"token":"$token","context":{}}')});
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LoginForm(bloc: rig.bloc)))));
        await _settle(tester);
        await tester.enterText(find.byType(TextField).at(0), 'a@b.c');
        await tester.enterText(find.byType(TextField).at(1), 'segredo');
        await tester.tap(find.text('ENTRAR'));
        await _settle(tester);
        expect(rig.states.last, isA<AuthAuthenticated>(), reason: token);
        expect([_dialogTexts(tester), find.byType(CircularProgressIndicator).evaluate().length], [isEmpty, 0], reason: token);
        // a guarda de verdade (Modular com o ApiClient e o LocalPrefs do login)
        Modular.init(_GuardModule(rig.api, rig.prefs));
        final allowed = await tester.runAsync(() async => SetesAuthGuard().canActivate('/home/', ChildRoute('/home', child: (_, __) => const SizedBox())));
        Modular.destroy();
        expect([allowed, isJwtExpired(token)], [false, true], reason: token);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(rig.close);
      }
      expect(File(_guardSrc).readAsStringSync(), contains('if (client.token != null && !isJwtExpired(client.token!)) return true;'));
    });

    // --- LE-ADV-03 — seleção sem lista -------------------------------------------------------------------------------------------
    _supersededWidgets('[FATO LE-ADV-03] seleção com `institutions: []` (o `selectionToken` veio, a lista não): o login vai para a tela "Escolha '
        'o estabelecimento" VAZIA com "Avançar" desabilitado e nenhuma saída na tela (a navegação foi `navigate` — sem voltar); a guarda do '
        'LD-ADV-01 só recusa quando faltam os DOIS tokens', (tester) async {
      final rig = _AuthRig({'/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":[]}')});
      rig.bloc.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      await _settle(tester);
      expect(_describe(rig.states.last), 'seleção(0)');
      await tester.pumpWidget(MaterialApp(home: SelectInstitutionPage(bloc: rig.bloc)));
      await _settle(tester);
      expect(find.text('Escolha o estabelecimento'), findsOneWidget);
      expect(find.byIcon(Icons.business_outlined), findsNothing);   // nenhum estabelecimento para tocar
      expect(find.text('Definir como padrão'), findsOneWidget);
      final button = tester.widget<SetesButton>(find.byType(SetesButton));
      expect([button.label, button.onPressed], ['Avançar', null]);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(rig.close);
    });

    test('[CORRIGIDO — seleção sem estabelecimentos = ilegível; era o ACHADO LE-ADV-03 LOW] seleção sem estabelecimento para escolher = resposta ilegível (o setes-api nunca manda: 0 vínculos é 403 '
        'e 1 vínculo é token direto — auth.service.ts:69/74)', () async {
      final rig = _AuthRig({'/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":[]}')});
      await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
      await rig.close();
      expect(_describe(rig.states.last), 'erro técnico Failure/$_invalid/INVALID_RESPONSE · setes-api');
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 2. `envelopeOk` × as rotas REAIS do setes-api (só leitura)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(2) envelopeOk × rotas reais', () {
    test('[RESISTIU] as 10 leituras do core contra as formas EXATAS que auth.routes.ts e core.routes.ts devolvem no 2xx: todas entram '
        '(nenhuma rota real é recusada pelo `envelopeOk`)', () async {
      final jwt = _jwt(exp: _epoch(const Duration(hours: 12)));
      final real = <String, String>{
        'POST /auth/login': '{"ok":true,"token":"$jwt","context":{"isSalesman":true}}',
        'POST /auth/select-institution': '{"ok":true,"token":"$jwt","context":{}}',
        'POST /auth/recovery-password': '{"ok":true,"message":"Se o email existir, um código de recuperação foi enviado"}',
        'POST /auth/change-password': '{"ok":true}',
        'GET /api/core/me': '{"ok":true,"data":{"userId":7,"name":"Valdo","email":"v@setes.example","institutionId":1,'
            '"institutionName":"Setes","profile":"admin","context":{}}}',
        'GET /api/core/menus': '{"ok":true,"data":[]}',
        'GET /api/core/preferences': '{"ok":true,"data":{"locale":"pt"}}',
        'PUT /api/core/preferences': '{"ok":true}',
        'GET /api/core/theme': '{"ok":true,"data":{"primaryColor":"#112233","secondaryColor":null,"logoBase64":null}}',
        'PUT /api/core/theme': '{"ok":true}',
      };
      final api = ApiClient(
        client: MockClient((req) async => _r(real['${req.method} ${req.url.path}'] ?? '{"error":"rota"}', real.containsKey('${req.method} ${req.url.path}') ? 200 : 404)),
        baseUrl: _base,
        session: ProductToken()..value = jwt,
      );
      final auth = AuthRepositoryImpl(datasource: AuthRemoteDatasource(client: api));
      final results = <String, Either<Failure, Object?>>{
        'login': await auth.login('a@b.c', 'x'),
        'seleção': await auth.selectInstitution('sel', 1),
        'recuperação': await auth.recoveryPassword('a@b.c'),
        'troca de senha': await auth.changePassword('a@b.c', '123', 'nova123'),
        'me': await auth.getMe(),
        'menus': await MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: api)).getMenus(),
        'preferências get': await PreferenceRepositoryImpl(datasource: PreferenceRemoteDatasource(client: api)).getAll(),
        'preferências put': await PreferenceRepositoryImpl(datasource: PreferenceRemoteDatasource(client: api)).save('locale', 'pt'),
        'tema get': await ThemeRepositoryImpl(datasource: ThemeRemoteDatasource(client: api)).getTheme(),
        'tema put': await ThemeRepositoryImpl(datasource: ThemeRemoteDatasource(client: api)).saveTheme(primaryColor: '#112233'),
      };
      expect({for (final e in results.entries) e.key: e.value.fold((f) => 'FALHA ${f.code} ${f.message}', (_) => 'ok')},
          {for (final k in results.keys) k: 'ok'});
    });

    final apiDir = Directory(Platform.environment['SETES_API_DIR'] ?? '../../../setes-api-f2a');
    test('[RESISTIU] cerca das ROTAS (lê setes-api/src/modules/auth/auth.routes.ts e core/core.routes.ts — só leitura): todo `res.json` '
        'sem `.status(...)` (o 2xx) leva `ok: true`; nenhum `res.send`/`sendStatus` nos dois routers; as 10 rotas que o core chama '
        'existem; e os routers estão montados em /auth e /api/core', () {
      final authSrc = File('${apiDir.path}/src/modules/auth/auth.routes.ts').readAsStringSync();
      final coreSrc = File('${apiDir.path}/src/modules/core/core.routes.ts').readAsStringSync();
      final success = <String>[];
      for (final src in [authSrc, coreSrc]) {
        for (final m in RegExp(r'res(\.status\([^)]*\))?\.json\(([^\n]*)').allMatches(src)) {
          if (m.group(1) == null) success.add(m.group(2)!);
        }
        expect(RegExp(r'res\.(send|sendStatus)\(').hasMatch(src), isFalse);
      }
      expect(success.length, greaterThanOrEqualTo(10));
      expect(success.where((b) => !b.contains('ok: true')).toList(), isEmpty);
      for (final route in ["router.post('/login'", "router.post('/select-institution'", "router.post('/recovery-password'",
        "router.post('/change-password'"]) {
        expect(authSrc, contains(route));
      }
      for (final route in ["router.get('/me'", "router.get('/menus'", "router.get('/preferences'", "router.put('/preferences'",
        "router.get('/theme'", "router.put('/theme'"]) {
        expect(coreSrc, contains(route));
      }
      final appSrc = File('${apiDir.path}/src/app.ts').readAsStringSync();
      expect(appSrc, contains("app.use('/auth', rateLimitMiddleware, authRoutes)"));
      // o 2xx que NÃO é envelope no app.ts é só o preflight do CORS (OPTIONS 204 — o navegador nunca o entrega ao app)
      expect(RegExp(r'sendStatus\((\d+)\)').allMatches(appSrc).map((m) => m.group(1)).toList(), ['204']);
    }, skip: apiDir.existsSync() ? false : 'setes-api ausente (defina SETES_API_DIR)');

    // --- LE-ADV-04 — o código curto só numa das portas ----------------------------------------------------------------------------
    _supersededWidgets('[FATO LE-ADV-04] a MESMA resposta ilegível (o Plesk devolvendo HTML 200) tem o código curto da D-F216 SÓ quando passa '
        'pelo `invalidResponseFailure`: no leitor do core sai "Informe o código INVALID_RESPONSE · setes-api"; no envelope ESTRITO do '
        '`_send` (TODA leitura/ato da nfse-api — o caso típico da NFSE_API_URL torta), no `envelopeData` e no `envelopePage` (a lista de '
        'OS, a fotografia, a aba Emissor fiscal) sai `supportRef: null` — o diálogo diz "acione o suporte" sem código e o suporte não '
        'sabe QUAL serviço respondeu torto; nada vai ao console', (tester) async {
      final logs = <String?>[];
      final saved = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      late Failure core;
      Failure? strict;
      Failure? data;
      Failure? page;
      try {
        await tester.runAsync(() async {
          final html = MockClient((_) async => _r('<html>Plesk</html>'));
          core = (await MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: ApiClient(client: html, baseUrl: _base))).getMenus())
              .fold((l) => l, (_) => const Failure(message: 'ok?'));
          try {
            await NfseApiClient(client: html, baseUrl: _nfseBase).get('/v1/emitter');
          } on Failure catch (f) {
            strict = f;
          }
          try {
            envelopeData(const {}, service: 'nfse-api');
          } on Failure catch (f) {
            data = f;
          }
          try {
            envelopePage(const {'ok': true}, service: 'setes-api');
          } on Failure catch (f) {
            page = f;
          }
        });
      } finally {
        debugPrint = saved;
      }
      expect([core.code, core.supportRef], [_invalid, 'INVALID_RESPONSE · setes-api']);
      expect([strict!.code, strict!.supportRef, strict!.statusCode], [_invalid, null, 200]);
      expect([data!.code, data!.supportRef, page!.code, page!.supportRef], [_invalid, null, _invalid, null]);
      expect(logs.where((l) => l!.contains('resposta ilegível')).length, 1);   // só a do core
      await tester.pumpWidget(MaterialApp(home: Builder(
          builder: (context) => TextButton(onPressed: () => showFailureFeedback(context, strict!), child: const Text('abrir')))));
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      final texts = _dialogTexts(tester);
      expect(texts, containsAll(['Erro', 'O servidor respondeu num formato inesperado (acione o suporte)']));
      expect(texts.any((t) => t.startsWith('Informe o código')), isFalse);
    });

    test('[CORRIGIDO — D-F216 nas três portas do envelope; era o ACHADO LE-ADV-04 LOW] D-F216 em TODA porta do envelope: o estrito do `_send` (pelo `serviceLabel`), o `envelopeData` e o '
        '`envelopePage` também levam `INVALID_RESPONSE · <serviço>` (e o console), como o `invalidResponseFailure`', () async {
      final html = MockClient((_) async => _r('<html>Plesk</html>'));
      Failure? strict;
      try {
        await NfseApiClient(client: html, baseUrl: _nfseBase).get('/v1/emitter');
      } on Failure catch (f) {
        strict = f;
      }
      expect(strict!.supportRef, 'INVALID_RESPONSE · nfse-api');
      Failure? data;
      try {
        envelopeData(const {}, service: 'nfse-api');
      } on Failure catch (f) {
        data = f;
      }
      expect(data!.supportRef, startsWith('INVALID_RESPONSE'));
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 3. D-F214 — a natureza dos diálogos nas DUAS pontes; D-F138 e D-F148 intactos
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(3) D-F214 × as duas pontes', () {
    testWidgets('[RESISTIU] a matriz de 13 falhas nas DUAS pontes (app `showFailureFeedback` × core `showAuthFailureDialog`): os 3 códigos '
        'do cliente são "Erro" com e sem ref/status; o código de SERVIDOR que começa com `CLIENT_` segue "Atenção" (a lista, nunca o '
        'prefixo); o 401 da sessão não abre diálogo na ponte do app (D-F138) e é "Atenção" no login; as duas pontes concordam em todo '
        'o resto', (tester) async {
      final cases = <String, (Failure, String?, String?)>{
        'invalidResponse sem ref nem status (envelopeData/Page)':
            (const Failure(message: 'core.errors.invalidResponse', code: _invalid), 'Erro', 'Erro'),
        'invalidResponse 200 sem ref (envelope estrito)':
            (const Failure(message: 'core.errors.invalidResponse', statusCode: 200, code: _invalid), 'Erro', 'Erro'),
        'invalidResponse com o código curto': (invalidResponseFailure('x', service: 'nfse-api'), 'Erro', 'Erro'),
        'configuration com ref': (const Failure(message: 'core.errors.configuration', code: ClientFailureCodes.configuration,
            supportRef: '(vazia)'), 'Erro', 'Erro'),
        'configuration sem ref': (const Failure(message: 'core.errors.configuration', code: ClientFailureCodes.configuration), 'Erro', 'Erro'),
        'sessionNotAccepted 401 sem ref': (const Failure(message: 'core.errors.sessionNotAccepted', statusCode: 401,
            code: ClientFailureCodes.sessionNotAccepted), 'Erro', 'Erro'),
        'sessionNotAccepted 401 com a origem': (const Failure(message: 'core.errors.sessionNotAccepted', statusCode: 401,
            code: ClientFailureCodes.sessionNotAccepted, supportRef: 'AUTH_KID_UNKNOWN: kid desconhecido'), 'Erro', 'Erro'),
        'servidor 422 com código `CLIENT_…`': (const Failure(message: 'Cliente inexistente', statusCode: 422, code: 'CLIENT_NOT_FOUND'),
            'Atenção', 'Atenção'),
        '409 de negócio': (const Failure(message: 'Ordem já faturada', statusCode: 409, code: 'ORDER_INVOICED'), 'Atenção', 'Atenção'),
        '400 sem código': (const Failure(message: 'Body inválido', statusCode: 400), 'Atenção', 'Atenção'),
        '500': (const Failure(message: 'Erro interno', statusCode: 500), 'Erro', 'Erro'),
        'rede': (NetworkFailure(detail: networkFailureCode('nfse-api')), 'Erro', 'Erro'),
        '401 da sessão (UnauthorizedFailure)': (const UnauthorizedFailure(message: 'Token inválido'), null, 'Atenção'),
      };
      Future<String?> titleOf(void Function(BuildContext) show) async {
        await tester.pumpWidget(MaterialApp(home: Builder(
            builder: (context) => Scaffold(body: TextButton(onPressed: () => show(context), child: const Text('abrir'))))));
        await tester.tap(find.text('abrir'));
        await _settle(tester);
        final texts = _dialogTexts(tester);
        final title = texts.contains('Erro') ? 'Erro' : texts.contains('Atenção') ? 'Atenção' : null;
        if (find.text('OK').evaluate().isNotEmpty) {
          await tester.tap(find.text('OK'));
          await _settle(tester);
        }
        return title;
      }

      final got = <String, (String?, String?)>{};
      for (final MapEntry(key: name, value: (f, _, _)) in cases.entries) {
        got[name] = (await titleOf((c) => showFailureFeedback(c, f)), await titleOf((c) => showAuthFailureDialog(c, f)));
        if (f is! UnauthorizedFailure) expect(got[name]!.$1, got[name]!.$2, reason: 'as pontes divergem em $name');
      }
      expect(got, {for (final MapEntry(key: n, value: (_, app, core)) in cases.entries) n: (app, core)});
    });

    test('[RESISTIU] cerca da D-F214: `ClientFailureCodes.all` = TODOS os `static const` de código da classe, e as duas pontes leem a '
        'LISTA (`ClientFailureCodes.all.contains(failure.code)`) — código novo do cliente entra nas duas por construção', () {
      final src = File(_apiClientSrc).readAsStringSync();
      final body = RegExp(r'abstract final class ClientFailureCodes \{([\s\S]*?)\n\}').firstMatch(src)!.group(1)!;
      final declared = RegExp(r"static const \w+ = '([A-Z_]+)';").allMatches(body).map((m) => m.group(1)).toSet();
      expect(declared, ClientFailureCodes.all);
      expect(ClientFailureCodes.all.length, 4);   // D-F219: + CLIENT_CLOCK
      for (final path in [_appFeedbackSrc, _coreFeedbackSrc]) {
        expect(File(path).readAsStringSync(), contains('ClientFailureCodes.all.contains(failure.code)'), reason: path);
      }
    });

    test('[RESISTIU] D-F138 e D-F148 não mudaram: (a) 401 do setes-api numa leitura do core com a sessão → `UnauthorizedFailure` e a '
        'sessão expira UMA vez (o `envelopeOk` nem chega a ver o corpo); (b) o 401 da nfse-api pergunta ao EMISSOR — `/me` 200 (envelope '
        'ou não) ou 503 = a sessão vive e a falha é `SESSION_NOT_ACCEPTED` (401, com a origem); `/me` 401 = a sessão morreu', () async {
      final token = ProductToken()..value = 'jwt-a';
      var expired = 0;
      token.addExpiredListener(() => expired++);
      final api = ApiClient(client: MockClient((_) async => _r('{"error":"Token inválido ou expirado"}', 401)), baseUrl: _base, session: token);
      final menus = (await MenuRepositoryImpl(datasource: MenuRemoteDatasource(client: api)).getMenus()).fold((l) => l, (_) => null);
      final theme = (await ThemeRepositoryImpl(datasource: ThemeRemoteDatasource(client: api)).getTheme()).fold((l) => l, (_) => null);
      expect([menus is UnauthorizedFailure, theme is UnauthorizedFailure, token.value, expired], [true, true, null, 1]);

      final confirmations = <String, (int, String, String)>{
        '/me 200 envelope': (200, '{"ok":true,"data":{}}', 'vive'),
        '/me 200 HTML (proxy)': (200, '<html>x</html>', 'vive'),
        '/me 503': (503, '{"error":"indisponível"}', 'vive'),
        '/me 401': (401, '{"error":"Token inválido"}', 'morreu'),
      };
      for (final MapEntry(key: name, value: (status, body, want)) in confirmations.entries) {
        final t = ProductToken()..value = 'jwt-c';
        var died = 0;
        t.addExpiredListener(() => died++);
        final erp = ApiClient(client: MockClient((_) async => _r(body, status)), baseUrl: _base, session: t);
        t.confirmer = erp.sessionAlive;
        final nfse = NfseApiClient(
            client: MockClient((_) async => _r('{"error":"kid desconhecido","code":"AUTH_KID_UNKNOWN"}', 401)), baseUrl: _nfseBase, session: t);
        Failure? got;
        try {
          await nfse.get('/v1/emitter');
        } on Failure catch (f) {
          got = f;
        }
        if (want == 'vive') {
          expect([got is UnauthorizedFailure, got!.code, got.statusCode, got.supportRef, t.value, died],
              [false, ClientFailureCodes.sessionNotAccepted, 401, 'AUTH_KID_UNKNOWN: kid desconhecido', 'jwt-c', 0], reason: name);
        } else {
          expect([got is UnauthorizedFailure, t.value, died], [true, null, 1], reason: name);
        }
      }
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 4. D-F217 — o recuo "página esvaziou"
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(4) D-F217 × recuo de página', () {
    test('[RESISTIU] fuzz (300 sementes × 3 servidores — consistente, COUNT incoerente ±12, sem `pageSize` no corpo; 25 ações cada: página '
        'da barra, a barra velha +1, operação que tira OS e recarrega, OS novas, troca de tamanho, lote): (O1) nunca mais de 2 GETs para '
        'UMA ação; (O2) nunca spinner preso; (O3) no servidor consistente a tela nunca fica numa página além da última com OS na aba '
        '(o recuo legítimo segue valendo)', () async {
      final out = _FuzzOut();
      final seeds = int.tryParse(Platform.environment['LE_SEEDS'] ?? '') ?? 300;
      for (var seed = 1; seed <= seeds; seed++) {
        for (final mode in ['consistente', 'COUNT incoerente', 'sem pageSize']) {
          await _pageFuzz(seed, mode, out);
        }
      }
      // ignore: avoid_print
      print('fuzz D-F217: ${out.counts}');
      expect(out.violations.take(10).toList(), isEmpty);
      for (final mode in ['consistente', 'COUNT incoerente', 'sem pageSize']) {
        expect(out.counts['$mode: recuo'] ?? 0, greaterThan(0), reason: 'o fuzz exercitou o recuo em "$mode"');
      }
    }, timeout: const Timeout(Duration(minutes: 6)));

    test('[RESISTIU] o recuo LEGÍTIMO pelo fluxo de verdade: (a) o LOTE fatura a única OS da página 3 → a recarga final pede a 3 (vazia, '
        'total 20) e recua para a 2; (b) "Cancelar OS" na única OS da página 3 → a lista volta e recua para a 2; (c) a página 1 vazia com '
        'total > 0 (COUNT incoerente) fica — 1 GET; (d) sem `pageSize` no corpo: a página 3 vazia recua para a 1 e para', () async {
      Future<(List<int>, ServiceOrderListState)> run(Future<void> Function(ServiceOrderBloc bloc, _ListServer server, ServiceOrderRepoMock repo) act,
          {int rows = 21, bool sendPageSize = true}) async {
        final server = _ListServer(rows: rows, sendPageSize: sendPageSize);
        final repo = ServiceOrderRepoMock();
        when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
            .thenAnswer((inv) async => Right(server.answer(inv.namedArguments[#page] as int, inv.namedArguments[#pageSize] as int?)));
        final bloc = buildServiceOrderBloc(repo: repo);
        final states = <ServiceOrderState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
        await pumpEventQueue(times: 40);
        await act(bloc, server, repo);
        await pumpEventQueue(times: 200);
        await sub.cancel();
        await bloc.close();
        return (server.pages, states.whereType<ServiceOrderListState>().last);
      }

      final (batchPages, batchEnd) = await run((bloc, server, repo) async {
        when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async {
          server.rows = 20;
          return Right(BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: 21, ok: true)]));
        });
        bloc.add(const ServiceOrderListRequested(page: 3));
        await pumpEventQueue(times: 40);
        bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [21], input: _input));
      });
      expect([batchPages, batchEnd.page, batchEnd.items.length, batchEnd.loading], [[1, 3, 3, 2], 2, 10, false]);

      final (cancelPages, cancelEnd) = await run((bloc, server, repo) async {
        when(() => repo.getById(21)).thenAnswer((_) async => const Right(ServiceOrderFull(id: 21, number: 7021, customerId: 1)));
        when(() => repo.cancel(21)).thenAnswer((_) async {
          server.rows = 20;
          return const Right(unit);
        });
        bloc.add(const ServiceOrderListRequested(page: 3));
        await pumpEventQueue(times: 40);
        bloc.add(const ServiceOrderViewRequested(21));
        await pumpEventQueue(times: 40);
        bloc.add(const ServiceOrderCancelRequested(21));
      });
      expect([cancelPages, cancelEnd.page, cancelEnd.items.length], [[1, 3, 3, 2], 2, 10]);

      final repo1 = ServiceOrderRepoMock();
      var calls1 = 0;
      when(() => repo1.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async {
        calls1++;
        return Right(_listPage(const [], total: 5));
      });
      final bloc1 = buildServiceOrderBloc(repo: repo1);
      bloc1.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 100);
      await bloc1.close();
      expect(calls1, 1);

      final (noSizePages, noSizeEnd) = await run((bloc, server, repo) async {
        server.rows = 20;   // a página 3 esvaziou por fora
        bloc.add(const ServiceOrderListRequested(page: 3));
      }, rows: 30, sendPageSize: false);
      expect([noSizePages, noSizeEnd.page, noSizeEnd.loading], [[1, 3, 1], 1, false]);
    });

    _superseded('[FATO LE-ADV-05] a guarda da D-F217 compara a página da RESPOSTA (`paged.page > paged.pageCount`), não a PEDIDA: uma resposta '
        'que não segue a página pedida (o mesmo corpo para toda página — proxy/cache que ignora a query; aqui: sempre `page: 2, data: [], '
        'total: 5`) recua para a 1, pede a 1, recebe de novo a "2" e recua de novo — o laço da LD-ADV-10 por outra porta (o mock só para '
        'no 41º GET)', () async {
      final repo = ServiceOrderRepoMock();
      final pages = <int>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        pages.add(inv.namedArguments[#page] as int);
        if (pages.length == 1) return Right(_listPage([1, 2], total: 12));
        return pages.length <= 41 ? Right(_listPage(const [], page: 2, total: 5)) : Right(_listPage([1]));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(page: 2));
      await pumpEventQueue(times: 3000);
      await bloc.close();
      expect(pages.length, greaterThanOrEqualTo(42));
      expect(pages.sublist(0, 5), [1, 2, 1, 1, 1]);
    });

    test('[CORRIGIDO — recuo pela página PEDIDA; era o ACHADO LE-ADV-05 LOW] o recuo só quando a página PEDIDA passou do total — e o alvo é sempre MENOR que a pedida (termina por '
        'construção): o mesmo servidor faz no máximo 2 GETs para o clique', () async {
      final repo = ServiceOrderRepoMock();
      final pages = <int>[];
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        pages.add(inv.namedArguments[#page] as int);
        if (pages.length == 1) return Right(_listPage([1, 2], total: 12));
        return pages.length <= 41 ? Right(_listPage(const [], page: 2, total: 5)) : Right(_listPage([1]));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(page: 2));
      await pumpEventQueue(times: 3000);
      await bloc.close();
      expect(pages.length, lessThanOrEqualTo(3));
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 5. `isClosed` antes da recarga final (LD-ADV-06)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(5) isClosed × rotina mensal e fotografia', () {
    test('[RESISTIU] rotina mensal e fotografia × (trabalho ok | falha) × (bloc fechado ANTES do trabalho voltar | DURANTE a recarga '
        'final): nenhuma requisição nova depois do close, nenhum erro não tratado; e o CONTROLE (sem fechar) ainda recarrega e a trava '
        'solta (a 2ª execução toma)', () async {
      final report = <String, (int, int)>{};
      for (final kind in ['monthly', 'pending']) {
        for (final fail in [false, true]) {
          for (final when_ in ['antes do trabalho', 'durante a recarga final']) {
            late _Park rig;
            final errors = await _guarded(() async {
              rig = _Park();
              await rig.add(const ServiceOrderListRequested(status: 'F', filter: ''));
              await rig.finish('list');
              await rig.add(_longEvent(kind));
              if (when_ == 'antes do trabalho') {
                await rig.close();
                await rig.finish(kind, failure: fail ? _erpDown : null);
              } else {
                await rig.finish(kind, failure: fail ? _erpDown : null);
                expect(rig.parked('list'), 1, reason: '$kind: a recarga final saiu');
                await rig.close();
                await rig.finish('list');
              }
              await rig.drain();
            });
            final name = '$kind ${fail ? 'falha' : 'ok'} $when_';
            expect(errors, isEmpty, reason: name);
            expect(rig.flights, isEmpty, reason: name);
            report[name] = (rig.listCallsAfterClose, rig.listCalls);
          }
        }
        // controle: sem fechar — a recarga final acontece e a trava solta antes dela (a 2ª execução toma com a recarga ainda no ar)
        final rig = _Park();
        await rig.add(const ServiceOrderListRequested(status: 'F', filter: ''));
        await rig.finish('list');
        await rig.add(_longEvent(kind));
        await rig.finish(kind);
        expect(rig.parked('list'), 1, reason: '$kind controle: recarga final');
        await rig.add(_longEvent(kind));
        expect(rig.parked(kind), 1, reason: '$kind controle: a trava soltou antes da recarga final (D-F169)');
        await rig.drain();
        await rig.close();
      }
      expect(report.values.map((v) => v.$1).toSet(), {0});
      expect({for (final e in report.entries) e.key: e.value.$2}, {
        'monthly ok antes do trabalho': 1,
        'monthly ok durante a recarga final': 2,
        'monthly falha antes do trabalho': 1,
        'monthly falha durante a recarga final': 2,
        'pending ok antes do trabalho': 1,
        'pending ok durante a recarga final': 2,
        'pending falha antes do trabalho': 1,
        'pending falha durante a recarga final': 2,
      });
    });

    test('[RESISTIU] cerca de fonte: o `if (isClosed) return;` vem LOGO depois do trabalho e dentro do `try` cujo `finally` devolve a trava '
        'da MESMA operação (a trava solta mesmo no retorno antecipado)', () {
      final src = File(_blocSrc).readAsStringSync();
      for (final (work, lock) in [('await monthlyRun(event.year, event.month);', '_monthlyLock'), ('await fiscalPending();', '_fiscalPendingLock')]) {
        final i = src.indexOf(work);
        expect(i, greaterThan(0), reason: work);
        final tail = src.substring(i, i + 2200);
        expect(RegExp(r'^\s*if \(isClosed\) return;').hasMatch(tail.substring(work.length).split('\n')[1]), isTrue, reason: work);
        expect(RegExp('finally \\{\\s*$lock\\.release\\(run\\);').hasMatch(tail), isTrue, reason: work);
      }
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 6. Seleção × falha pela PÁGINA de verdade
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(6) seleção × falha', () {
    testWidgets('[RESISTIU] E2E do PSO-ADV-02 com a assinatura nova: marca 2 OS, o lote fatura uma e recusa a outra, a recarga final '
        'FALHA ("Não foi possível carregar a lista." + os dois diálogos) — ao fechar o relatório fica marcada SÓ a recusada (contador 1, '
        'botão armado); "Tentar novamente" carrega a MESMA lista e a recusada continua marcada', (tester) async {
      final repo = ServiceOrderRepoMock();
      var loads = 0;
      var failNext = false;
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        loads++;
        if (failNext) {
          failNext = false;
          return Left(_erpDown);
        }
        return Right(_listPage(loads == 1 ? [1, 2] : [2], page: inv.namedArguments[#page] as int));
      });
      when(() => repo.batchInvoice(any(), any())).thenAnswer((_) async {
        failNext = true;
        return Right(BatchInvoiceReport.fromEntries(const [
          BatchInvoiceEntry(orderId: 1, ok: true, invoiceNumber: '10'),
          BatchInvoiceEntry(orderId: 2, ok: false, error: 'Sem forma de pagamento'),
        ]));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await _settle(tester);
      expect(_batchBadge(tester), (2, true));
      bloc.add(const ServiceOrderBatchInvoiceRequested(orderIds: [1, 2], input: _input));
      await _settle(tester);
      expect(find.text('Não foi possível carregar a lista.'), findsOneWidget);
      await tester.tap(find.text('OK'));   // o diálogo da falha da recarga (por cima do relatório)
      await _settle(tester);
      await tester.tap(find.text('Fechar'));   // o relatório do lote
      await _settle(tester);
      expect(_batchBadge(tester), (1, true));
      await tester.tap(find.text('Tentar novamente'));
      await _settle(tester);
      expect(find.text('Não foi possível carregar a lista.'), findsNothing);
      expect(_batchBadge(tester), (1, true));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await dispose();
    });

    Future<(int, bool)> markThenFailed(WidgetTester tester, ServiceOrderEvent change) async {
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
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect(find.text('Não foi possível carregar a lista.'), findsOneWidget);
      final badge = _batchBadge(tester);
      await dispose();
      return badge;
    }

    testWidgets('[RESISTIU] a troca de TAMANHO que falha limpa a seleção (o lote nunca fica armado com OS que a tela não mostra)',
        (tester) async {
      expect(await markThenFailed(tester, const ServiceOrderListRequested(pageSize: 25)), (0, false));
    });

    testWidgets('[RESISTIU] o CRITÉRIO da pesquisa avançada que falha (rede — não é recusa de critério) limpa a seleção', (tester) async {
      expect(await markThenFailed(tester, const ServiceOrderListRequested(criteria: SearchCriteriaValues({'customer': 'Cliente 9'}))),
          (0, false));
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 7. Resíduos da regra das linhas e da D-F215
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(7) linhas sem âncora e console', () {
    _supersededWidgets('[FATO LE-ADV-06] a regra "no modo `all` a linha é só a mensagem — o `field` é o nome técnico `event`/`dps`, ruído" '
        '(LD-SOC-01 × LD-ADV-07) ficou só no `FISCAL_CANCEL_REFUSED`: a recusa da TRANSMISSÃO (`FISCAL_DPS_REJECTED`, a forma REAL de '
        'fiscal-api https-json.ts:261 — `{field: "dps", message: "E0116: …"}`) ainda mostra "• dps: E0116: …"', (tester) async {
      final repo = ServiceOrderRepoMock();
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => const Left(Failure(
                message: 'Fisco rejeitou (400): E0116: Inscrição municipal do prestador obrigatória',
                statusCode: 422,
                code: 'FISCAL_DPS_REJECTED',
                fields: [FailureField(field: 'dps', message: 'E0116: Inscrição municipal do prestador obrigatória')],
              )));
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      final text = _dialogTexts(tester).join('\n');
      expect(text, contains('• dps: E0116: Inscrição municipal do prestador obrigatória'));
      await tester.tap(find.text('OK'));
      await _settle(tester);
      await dispose();
      expect(File(_pageSrc).readAsStringSync(), contains("'• \${[f.field, f.message].where((s) => s.isNotEmpty).join(': ')}'"));
    });

    testWidgets('[CORRIGIDO — a linha da recusa sem o nome técnico; era o ACHADO LE-ADV-06 LOW] a recusa da transmissão segue a MESMA regra das linhas do `all`: "• E0116: …" (o código E já vem '
        'na mensagem), sem o nome técnico `dps:`', (tester) async {
      final repo = ServiceOrderRepoMock();
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) async => const Left(Failure(
                message: 'Fisco rejeitou (400): E0116: Inscrição municipal do prestador obrigatória',
                statusCode: 422,
                code: 'FISCAL_DPS_REJECTED',
                fields: [FailureField(field: 'dps', message: 'E0116: Inscrição municipal do prestador obrigatória')],
              )));
      final bloc = buildServiceOrderBloc(repo: repo);
      final dispose = await _pumpPage(tester, bloc);
      final text = _dialogTexts(tester).join('\n');
      await tester.tap(find.text('OK'));
      await _settle(tester);
      await dispose();
      expect(text, allOf(contains('• E0116: Inscrição municipal do prestador obrigatória'), isNot(contains('dps:'))));
    });

    test('[RESISTIU] D-F215 nas formas REAIS da exceção (http 1.6.0: `ClientException: <msg>, uri=<url>`, a de socket do IOClient '
        '`ClientException with SocketException: …, uri=<url>`, mensagem com quebra de linha, o abort do navegador) × caminhos com CPF, '
        'filtro digitado e critério: o console leva serviço + caminho SEM a query + a causa, nunca o documento nem o `uri=`', () async {
      final forms = <String, Object Function(Uri)>{
        'fetch': (u) => http.ClientException('Failed to fetch', u),
        'XHR': (u) => http.ClientException('XMLHttpRequest error.', u),
        'quebra de linha': (u) => http.ClientException('Connection closed\nbefore full header was received', u),
        'socket do IOClient': (u) => _ClientSocketLike(u),
        'abort': (u) => http.RequestAbortedException(u),
      };
      const paths = [
        '/api/entities/by-document?personType=F&document=12345678909',
        '/api/customers?filter=Jo%C3%A3o%20Silva%2012345678909&page=1&pageSize=25',
        '/api/service-orders?status=A&criteria=%7B%22document%22%3A%2212345678909%22%7D',
      ];
      final saved = debugPrint;
      final logs = <String?>[];
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      try {
        for (final MapEntry(key: name, value: boom) in forms.entries) {
          for (final path in paths) {
            logs.clear();
            final api = ApiClient(client: MockClient((req) async => throw boom(req.url)), baseUrl: _base);
            await expectLater(api.get(path), throwsA(isA<NetworkFailure>()));
            final line = logs.single!;
            expect(line, allOf(contains('falha de rede em setes-api ${path.split('?').first}'), isNot(contains('12345678909')),
                isNot(contains('uri=')), isNot(contains('api.setes.example'))), reason: '$name · $path');
          }
        }
      } finally {
        debugPrint = saved;
      }
    });

    _superseded('[FATO LE-ADV-07] o regex da D-F215 tira só o `, uri=…`: uma causa que EMBUTE a URL no texto (o fetch do navegador com '
        'credenciais na base — "Request cannot be constructed from a URL that includes credentials: <url>") leva a query com o documento '
        'ao console; e o próprio navegador registra a URL de toda falha de rede (net::ERR_FAILED / CORS) fora do alcance do app', () async {
      final saved = debugPrint;
      final logs = <String?>[];
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      try {
        final api = ApiClient(
            client: MockClient((req) async => throw http.ClientException(
                "Failed to execute 'fetch' on 'Window': Request cannot be constructed from a URL that includes credentials: ${req.url}", req.url)),
            baseUrl: 'https://u:p@api.setes.example');
        await expectLater(api.get('/api/entities/by-document?document=12345678909'), throwsA(isA<NetworkFailure>()));
      } finally {
        debugPrint = saved;
      }
      expect(logs.single, allOf(contains('12345678909'), isNot(contains(', uri='))));
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 8. As decisões do Valdo sobre as questões deste gate (2026-10-14) — D-F219 e D-F220
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('D-F219/D-F220 (decididos)', () {
    test('[DECIDIDO D-F219 (= LE-ADV-02 (a)) — era o FATO LE-ADV-02] o token que ESTE aparelho já dá por vencido (relógio adiantado além '
        'do `exp`) não entra: erro TÉCNICO `CLIENT_CLOCK` com a hora do aparelho no código (o login não volta mudo) e nada gravado como '
        'sessão; token sem `exp` legível = resposta ilegível (`INVALID_RESPONSE · setes-api`); o token bom entra', () async {
      Future<_AuthRig> loginWith(String token) async {
        final rig = _AuthRig({'/auth/login': (_) async => _r(jsonEncode({'ok': true, 'token': token}))});
        await rig.add(const AuthLoginRequested(email: 'a@b.c', password: 'x'));
        return rig;
      }

      final late = await loginWith(_jwt(exp: _epoch(const Duration(minutes: -5))));
      final clock = late.states.whereType<AuthError>().single.failure;
      expect([clock.code, clock.supportRef!.startsWith('CLOCK · '), isTechnicalFailure(clock), late.session.value,
        late.states.whereType<AuthAuthenticated>().length], [ClientFailureCodes.clock, true, true, null, 0]);
      await late.close();

      final noExp = await loginWith(_jwt());
      final bad = noExp.states.whereType<AuthError>().single.failure;
      expect([bad.code, bad.supportRef], [ClientFailureCodes.invalidResponse, 'INVALID_RESPONSE · setes-api']);
      await noExp.close();

      final good = await loginWith(_jwt(exp: _epoch(const Duration(hours: 1))));
      expect(good.states.whereType<AuthAuthenticated>().length, 1);
      await good.close();
    });

    test('[DECIDIDO D-F220 (= LE-ADV-07 (b)) — era o FATO LE-ADV-07] a causa que EMBUTE a URL no texto perde a query antes do console (o '
        'documento da busca nunca vai ao `debugPrint`); o caminho e a causa técnica ficam', () async {
      final saved = debugPrint;
      final logs = <String?>[];
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      try {
        final api = ApiClient(
            client: MockClient((req) async => throw http.ClientException(
                "Failed to execute 'fetch' on 'Window': Request cannot be constructed from a URL that includes credentials: ${req.url}", req.url)),
            baseUrl: 'https://u:p@api.setes.example');
        await expectLater(api.get('/api/entities/by-document?document=12345678909'), throwsA(isA<NetworkFailure>()));
      } finally {
        debugPrint = saved;
      }
      expect(logs.single, allOf(contains('/api/entities/by-document'), contains('includes credentials'), isNot(contains('12345678909'))));
    });
  });
}

/// A forma do `_ClientSocketException` do IOClient do http 1.6.0 (privada no pacote): `ClientException with <SocketException>, uri=<url>`.
class _ClientSocketLike extends http.ClientException {
  _ClientSocketLike(Uri uri) : super('Connection refused', uri);
  @override
  String toString() =>
      'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = api.interna, '
      'port = 3000, uri=$uri';
}
