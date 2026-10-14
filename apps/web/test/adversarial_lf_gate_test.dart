// GATE ADVERSARIAL independente do delta `5f6d3be..ebd040c` da F2b (setes-app, branch f2b — commit ebd040c "Gates do delta
// 60df1df..5f6d3be: D-F216 nas três portas, relógio do aparelho, D-F218…D-F220"), lado APP/telas (o lado core está em
// `packages/core/test/adversarial_lf_core_test.dart`):
//   - D-F219 na TELA: o `CLIENT_CLOCK` pelo LoginForm e pela tela de seleção (diálogo "Erro" com a frase do catálogo + o código de suporte);
//   - D-F216 pela CADEIA REAL da lista de OS (datasource + repositório + bloc) e da lista de pendentes da nfse-api, com corpos hostis;
//   - D-F217 por fuzz com servidores HOSTIS (eco da página errado, `page` 0, `pageSize` ≤ 0, `total` negativo/gigante, resposta aleatória) e
//     com respostas SOBREPOSTAS (a recuada de uma página não pode vencer a pedida depois);
//   - o ramo `FISCAL_DPS_REJECTED` da página nas formas que o PRODUTOR real emite (fiscal-api `https-json.ts:259-266`:
//     `{field: 'dps'|'event', message: '<código>: <texto>' | 'Fisco recusou (N) sem detalhar'}`);
//   - catálogo i18n: toda chave `core.errors.*` que o código usa existe nos DOIS idiomas.
// O que o gate anterior (`adversarial_le_gate_test.dart`) já cobre NÃO é repetido aqui.
//
// Convenção (a mesma dos gates anteriores):
//   - `[ACHADO LF-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje FALHA — `skip:`. Para ver a falha:
//         flutter test --run-skipped test/adversarial_lf_gate_test.dart
//   - `[FATO LF-ADV-NN]` = o comportamento atual registrado (roda sempre).
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
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
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_nfse_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_nfse_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/page/service_order_page.dart';
import 'package:setes_web/app/shared/search/search_criteria_datasource.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

import 'support/service_order_bloc_factory.dart';

const _base = 'https://api.setes.example';
const _nfseBase = 'https://nfse.setes.example';
const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
const _invalid = ClientFailureCodes.invalidResponse;

http.Response _r(String body, [int status = 200]) => http.Response(body, status, headers: _jsonHeaders);

String _jwt({required int exp, int? iat}) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'RS256', 'kid': 'k1'})}.${seg({'userId': 1, 'role': 'admin', if (iat != null) 'iat': iat, 'exp': exp})}.assinatura';
}

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

const _institutions = '[{"institutionId":1,"schemaName":"setes_a","name":"Empresa A","profile":"admin"},'
    '{"institutionId":2,"schemaName":"setes_b","name":"Empresa B","profile":"regular"}]';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

Iterable<String> _flatKeys(Map<String, dynamic> m, [String prefix = '']) sync* {
  for (final e in m.entries) {
    if (e.value is Map<String, dynamic>) {
      yield* _flatKeys(e.value as Map<String, dynamic>, '$prefix${e.key}.');
    } else {
      yield '$prefix${e.key}';
    }
  }
}

/// Corre [body] numa zona que GUARDA os erros não tratados em vez de derrubar o teste.
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
// Rig do LOGIN
// =====================================================================================================================================

class _Prefs extends LocalPrefs {
  String? saved;
  bool keep = false;
  int? defaultInstitution;
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
  Future<int?> getDefaultInstitutionId() async => defaultInstitution;
  @override
  Future<void> setDefaultInstitutionId(int? institutionId) async => defaultInstitution = institutionId;
}

typedef _Route = Future<http.Response> Function(http.Request req);

class _AuthRig {
  _AuthRig(Map<String, _Route> routes) {
    api = ApiClient(
      client: MockClient((req) async {
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
  }

  final session = ProductToken();
  final prefs = _Prefs();
  late final ApiClient api;
  late final AuthBloc bloc;

  Future<void> close() => bloc.close();
}

_Route _ok(String body) => (_) async => _r(body);

List<String> _dialogTexts(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '',
    ];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

// =====================================================================================================================================
// Página de OS de verdade
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

/// A recusa da transmissão com os [fields] dados, mostrada pela página (a tela de lista dispara o `getList` que falha com ela).
Future<String> _rejectionDialog(WidgetTester tester, List<FailureField> fields, {String message = 'Fisco rejeitou (400): …'}) async {
  final repo = ServiceOrderRepoMock();
  when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
      .thenAnswer((_) async => Left(Failure(message: message, statusCode: 422, code: 'FISCAL_DPS_REJECTED', fields: fields)));
  final bloc = buildServiceOrderBloc(repo: repo);
  final dispose = await _pumpPage(tester, bloc);
  final text = _dialogTexts(tester).join('\n');
  if (find.text('OK').evaluate().isNotEmpty) {
    await tester.tap(find.text('OK'));
    await _settle(tester);
  }
  await dispose();
  return text;
}

// =====================================================================================================================================
// Servidor da lista paginada (D-F217) — respostas HOSTIS
// =====================================================================================================================================

class _HostileServer {
  _HostileServer({required this.rows, required this.variant, required this.rnd});
  int rows;
  final String variant;
  final Random rnd;
  final requested = <int>[];

  /// A resposta CONSISTENTE do setes-api para (page, size); depois a variante a deforma.
  PagedResult<ServiceOrderListItem> answer(int page, int? size) {
    requested.add(page);
    final s = size == null || size <= 0 ? 10 : size;
    final start = (max(1, page) - 1) * s;
    final n = max(0, min(s, rows - start));
    List<ServiceOrderListItem> items(int count, int from) => [
          for (var i = 0; i < count; i++)
            ServiceOrderListItem(id: from + i + 1, number: 7000 + from + i + 1, customerId: 1, customerName: 'C', status: 'A'),
        ];
    switch (variant) {
      case 'eco da página errado (sempre 1)':
        return PagedResult(items: items(n, start), page: 1, pageSize: s, total: rows);
      case 'page 0':
        return PagedResult(items: items(n, start), page: 0, pageSize: s, total: rows);
      case 'pageSize 0':
        return PagedResult(items: items(n, start), page: page, pageSize: 0, total: rows);
      case 'pageSize negativo':
        return PagedResult(items: items(n, start), page: page, pageSize: -10, total: rows);
      case 'total negativo':
        return PagedResult(items: items(n, start), page: page, pageSize: s, total: -rows);
      case 'total gigante':
        return PagedResult(items: items(n, start), page: page, pageSize: s, total: 9000000000000000);
      case 'sempre vazio com total':
        return PagedResult(items: const [], page: page, pageSize: s, total: max(1, rows));
      case 'aleatório por resposta':
        return PagedResult(
            items: items(rnd.nextInt(11), 0), page: rnd.nextInt(60) - 5, pageSize: rnd.nextInt(60) - 10, total: rnd.nextInt(1200) - 20);
      default:
        throw StateError(variant);
    }
  }
}

const _variants = [
  'eco da página errado (sempre 1)',
  'page 0',
  'pageSize 0',
  'pageSize negativo',
  'total negativo',
  'total gigante',
  'sempre vazio com total',
  'aleatório por resposta',
];

void main() {
  final pt = _load('pt');
  final en = _load('en');

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 1. D-F219 na TELA — o diálogo do CLIENT_CLOCK
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(1) CLIENT_CLOCK nas telas', () {
    testWidgets('[RESISTIU] LoginForm real: o token que o relógio do aparelho já dá por vencido abre o diálogo "Erro" com a frase do catálogo '
        '("A data e a hora deste computador parecem erradas…") e "Informe o código CLOCK · <hora> ao suporte"; o botão não fica girando, '
        'nada inline, nada gravado (nem com "Manter conectado")', (tester) async {
      final rig = _AuthRig({'/auth/login': _ok(jsonEncode({'ok': true, 'token': _jwt(exp: _nowSec() - 30, iat: _nowSec() - 60)}))});
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LoginForm(bloc: rig.bloc)))));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.c');
      await tester.enterText(find.byType(TextField).at(1), 'segredo');
      await tester.tap(find.text('ENTRAR'));
      await _settle(tester);
      final texts = _dialogTexts(tester);
      expect(texts, contains('Erro'));
      expect(texts, contains((pt['core'] as Map)['errors']['clock']));
      expect(texts.where((t) => RegExp(r'^Informe o código CLOCK · \d{4}-\d\d-\d\dT[\d:.]+ ao suporte$').hasMatch(t)), hasLength(1));
      expect(texts.where((t) => t.contains('core.errors') || t.contains('Failure') || t.contains('subtype')), isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect([rig.session.value, rig.prefs.saved], [null, null]);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      // o operador corrige o relógio e tenta de novo: nova tentativa funciona (o estado de erro não prende o botão)
      expect(find.text('ENTRAR'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(rig.close);
    });

    test('[RESISTIU] a frase do CLOCK existe nos DOIS idiomas e é a única chave nova de `core.errors` (as chaves de `core.*` são idênticas em pt e en)',
        () {
      expect((pt['core'] as Map)['errors']['clock'], isNotEmpty);
      expect((en['core'] as Map)['errors']['clock'], isNotEmpty);
      expect(_flatKeys(pt['core'] as Map<String, dynamic>).toSet(), _flatKeys(en['core'] as Map<String, dynamic>).toSet());
    });

    test('[RESISTIU] CERCA do catálogo: toda chave `core.errors.*` / `auth.*` / `feedback.*` citada como literal em packages/core/lib existe em pt E en',
        () {
      final keys = <String>{};
      for (final f in Directory('../../packages/core/lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        keys.addAll(RegExp(r"'((?:core\.errors|auth|feedback)\.[A-Za-z0-9_.]+)'").allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
      }
      expect(keys.length, greaterThan(8));
      final have = {..._flatKeys(pt)};
      final haveEn = {..._flatKeys(en)};
      expect(keys.where((k) => !have.contains(k)), isEmpty, reason: 'faltam em pt');
      expect(keys.where((k) => !haveEn.contains(k)), isEmpty, reason: 'faltam em en');
    });

    testWidgets('[RESISTIU] a seleção de estabelecimento cujo JWT final já nasce vencido para o aparelho: diálogo "Erro" com o CLOCK, nada '
        'gravado, a tela cai no botão "Entrar" (como toda falha do select) — nunca no spinner nem em "autenticado" mudo', (tester) async {
      final rig = _AuthRig({
        '/auth/login': _ok('{"ok":true,"select":true,"selectionToken":"sel","institutions":$_institutions}'),
        '/auth/select-institution': _ok(jsonEncode({'ok': true, 'token': _jwt(exp: _nowSec() - 5)})),
      });
      rig.bloc.add(const AuthLoginRequested(email: 'a@b.c', password: 'x', keepConnected: true));
      await tester.runAsync(() => pumpEventQueue(times: 60));
      await tester.pumpWidget(MaterialApp(home: SelectInstitutionPage(bloc: rig.bloc)));
      await _settle(tester);
      await tester.tap(find.text('Empresa A'));
      await _settle(tester);
      await tester.tap(find.text('Avançar'));
      await tester.runAsync(() => pumpEventQueue(times: 60));
      await _settle(tester);
      final texts = _dialogTexts(tester);
      expect(texts, containsAll(['Erro', (pt['core'] as Map)['errors']['clock']]));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect([rig.session.value, rig.prefs.saved], [null, null]);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect(find.text('Entrar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(rig.close);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 2. D-F216 pela CADEIA REAL da lista de OS e das pendentes da nfse-api
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(2) D-F216 × cadeia real (datasource + repositório + bloc)', () {
    const secret = 'SEGREDO-12345678909';
    final hostile = <String, String>{
      'HTML do proxy': '<html>$secret</html>',
      'array': '[]',
      'null': 'null',
      'vazio': '',
      'ok:false': '{"ok":false,"error":"$secret"}',
      'ok sem data': '{"ok":true}',
      'data objeto': '{"ok":true,"data":{}}',
      'data texto': '{"ok":true,"data":"$secret"}',
      'item número': '{"ok":true,"data":[1]}',
      'item nulo': '{"ok":true,"data":[null]}',
      'item lista': '{"ok":true,"data":[[]]}',
      'total texto': '{"ok":true,"data":[],"total":"$secret"}',
      'page texto': '{"ok":true,"data":[],"page":"1"}',
      'pageSize objeto': '{"ok":true,"data":[],"pageSize":{}}',
      'total infinito (1e400)': '{"ok":true,"data":[],"total":1e400}',
    };

    test('[RESISTIU] a lista de OS (setes-api) com 16 corpos hostis: sempre `ServiceOrderActionFailure(CLIENT_INVALID_RESPONSE · setes-api)` e depois a '
        'lista em `loadFailed` ("Tentar novamente") — nunca spinner preso, nunca "lista vazia", nunca erro não tratado, nunca o corpo no console',
        () async {
      final logs = <String>[];
      final saved = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      try {
        for (final MapEntry(key: name, value: body) in hostile.entries) {
          final api = ApiClient(client: MockClient((_) async => _r(body)), baseUrl: _base);
          final repo = ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api));
          final bloc = buildServiceOrderBloc(repo: repo);
          final states = <ServiceOrderState>[];
          final sub = bloc.stream.listen(states.add);
          final errors = await _guarded(() async {
            bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
            await pumpEventQueue(times: 60);
          });
          await sub.cancel();
          await bloc.close();
          expect(errors, isEmpty, reason: name);
          final failure = states.whereType<ServiceOrderActionFailure>().single.failure;
          expect([failure.code, failure.supportRef], [_invalid, 'INVALID_RESPONSE · setes-api'], reason: name);
          final last = states.last as ServiceOrderListState;
          expect([last.loading, last.loadFailed, last.items], [false, true, isEmpty], reason: name);
        }
      } finally {
        debugPrint = saved;
      }
      expect(logs.where((l) => l.contains(secret)), isEmpty);
      expect(logs.length, hostile.length);
    });

    test('[RESISTIU] a lista de pendentes da nfse-api (cliente ESTRITO) com os mesmos corpos: o código curto é `INVALID_RESPONSE · nfse-api` '
        '(nunca o do setes-api), o ato fiscal os trata como desfecho DESCONHECIDO', () async {
      for (final MapEntry(key: name, value: body) in hostile.entries) {
        final api = NfseApiClient(client: MockClient((_) async => _r(body)), baseUrl: _nfseBase);
        final repo = ServiceOrderNfseRepositoryImpl(datasource: ServiceOrderNfseDatasourceImpl(client: api));
        final result = await repo.pending(page: 1, pageSize: 100);
        final failure = result.fold((l) => l, (r) => throw StateError('aceitou o corpo hostil "$name": $r'));
        expect([failure.code, failure.supportRef], [_invalid, 'INVALID_RESPONSE · nfse-api'], reason: name);
      }
    });

    test('[FATO LF-ADV-09] o item cujo `id`/`invoiceId` é ilegível (`{}`, `{"id":{"a":1}}`, `{"id":"x"}`) ENTRA na lista com id 0 (o `jsonInt` é tolerante): '
        'na lista de OS é uma linha que abre a OS 0 (404 de negócio) e na lista de PENDENTES da nfse-api é uma nota 0 no lote ("Transmitir '
        'pendentes" → `POST /v1/nfse/invoices/0/transmit` → 404 na linha do relatório). O produtor nunca emite isso (as duas rotas sempre '
        'levam o id) — LOW, defesa em profundidade: (a) descartar/recusar item sem id > 0 na leitura da página', () async {
      const body = '{"ok":true,"data":[{},{"id":{"a":1},"invoiceId":"x"}],"page":1,"pageSize":10,"total":2}';
      final api = ApiClient(client: MockClient((_) async => _r(body)), baseUrl: _base);
      final list = (await ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api)).getList('A', ''))
          .fold((l) => throw StateError('$l'), (r) => r);
      expect(list.items.map((i) => i.id).toList(), [0, 0]);
      final nfse = NfseApiClient(client: MockClient((_) async => _r(body)), baseUrl: _nfseBase);
      final pending = (await ServiceOrderNfseRepositoryImpl(datasource: ServiceOrderNfseDatasourceImpl(client: nfse)).pending())
          .fold((l) => throw StateError('$l'), (r) => r);
      expect(pending.items.map((i) => i.invoiceId).toList(), [0, 0]);
    });

    test('[FATO LF-ADV-06] o corpo CERTO mas sem metadados (`{ok:true,data:[]}`) é a lista VAZIA legítima (`total` 0) — uma API de OUTRO produto que '
        'também responda `{ok:true,data:[]}` na mesma rota passa por "Não encontramos nenhum registro"; é o limite da D-F206 (o envelope é o '
        'contrato; a identidade do servidor é da configuração `API_URL`)', () async {
      final api = ApiClient(client: MockClient((_) async => _r('{"ok":true,"data":[]}')), baseUrl: _base);
      final repo = ServiceOrderRepositoryImpl(datasource: ServiceOrderDatasourceImpl(client: api));
      final page = (await repo.getList('A', '')).fold((l) => throw StateError('$l'), (r) => r);
      expect([page.items, page.page, page.total], [isEmpty, 1, 0]);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 3. D-F217 × servidores HOSTIS e respostas SOBREPOSTAS
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(3) D-F217 × servidor hostil', () {
    test('[RESISTIU] fuzz (40 sementes × 8 servidores hostis × 22 ações): (O1) nunca mais de 2 GETs por ação nos servidores de regra FIXA (e '
        'nunca mais que a página pedida + 1 no aleatório — o recuo é estritamente decrescente); (O2) nunca spinner preso; (O3) nenhum erro '
        'não tratado; (O4) o recuo nunca pede a MESMA página duas vezes seguidas', () async {
      final violations = <String>[];
      final seeds = int.tryParse(Platform.environment['LF_SEEDS'] ?? '') ?? 40;
      for (var seed = 1; seed <= seeds; seed++) {
        for (final variant in _variants) {
          final rnd = Random(seed * 1000 + variant.length);
          final server = _HostileServer(rows: rnd.nextInt(90), variant: variant, rnd: rnd);
          final repo = ServiceOrderRepoMock();
          when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
              .thenAnswer((inv) async => Right(server.answer(inv.namedArguments[#page] as int, inv.namedArguments[#pageSize] as int?)));
          final bloc = buildServiceOrderBloc(repo: repo);
          final states = <ServiceOrderState>[];
          final sub = bloc.stream.listen(states.add);
          final errors = await _guarded(() async {
            bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
            await pumpEventQueue(times: 40);
            for (var step = 0; step < 22; step++) {
              final events = <(String, ServiceOrderEvent)>[
                ('página ${1 + rnd.nextInt(8)}', ServiceOrderListRequested(page: 1 + rnd.nextInt(8))),
                ('voltar à lista', const ServiceOrderBackToListPressed()),
                ('tamanho 25', const ServiceOrderListRequested(pageSize: 25)),
                ('lote tirou OS', const ServiceOrderBackToListPressed()),
              ];
              final (what, e) = events[rnd.nextInt(events.length)];
              if (what == 'lote tirou OS') server.rows = max(0, server.rows - rnd.nextInt(30));
              final before = server.requested.length;
              bloc.add(e);
              await pumpEventQueue(times: 60);
              final asked = server.requested.sublist(before);
              final why = '$variant semente $seed passo $step ($what, rows ${server.rows}): GETs $asked';
              final bound = variant == 'aleatório por resposta' ? 1 + (e is ServiceOrderListRequested ? e.page : 8) + 60 : 2;
              if (asked.length > bound) violations.add('(O1) $why');
              final last = states.whereType<ServiceOrderListState>().last;
              if (last.loading) violations.add('(O2) spinner preso — $why');
              for (var i = 1; i < asked.length; i++) {
                if (asked[i] == asked[i - 1]) violations.add('(O4) a MESMA página duas vezes seguidas — $why');
              }
            }
          });
          await sub.cancel();
          await bloc.close();
          if (errors.isNotEmpty) violations.add('(O3) $variant semente $seed: erro não tratado ${errors.first}');
        }
      }
      expect(violations.take(10).toList(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('[FATO LF-ADV-07] o bloc ADOTA a página e o tamanho da RESPOSTA sem clamp (`_page = paged.page; _pageSize = paged.pageSize`): uma resposta '
        'com `page: 0` / `pageSize: -10` (proxy de cache de OUTRA rota, servidor fora do contrato) vira a posição da tela e a PRÓXIMA '
        'requisição leva `page=0` / `pageSize=-10` — o setes-api real clampa (parseListQuery), então hoje é inofensivo; LOW, só defesa em '
        'profundidade (a D-F217 trata o laço, não o valor adotado)', () async {
      final seen = <(int, int?)>[];
      final repo = ServiceOrderRepoMock();
      when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((inv) async {
        seen.add((inv.namedArguments[#page] as int, inv.namedArguments[#pageSize] as int?));
        return Right(PagedResult<ServiceOrderListItem>(items: const [], page: 0, pageSize: -10, total: 0));
      });
      final bloc = buildServiceOrderBloc(repo: repo);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 40);
      bloc.add(const ServiceOrderBackToListPressed());
      await pumpEventQueue(times: 40);
      await bloc.close();
      expect(seen, [(1, null), (0, -10)]);
    });

    test('[RESISTIU] respostas SOBREPOSTAS: a página 4 em voo (que voltará vazia e recuaria) PERDE para a página 2 pedida depois — a recuada '
        'da resposta atrasada nunca derruba a página escolhida; e a ordem inversa (a 2 volta antes) termina igual', () async {
      for (final slowFirst in [true, false]) {
        final gates = <int, Completer<void>>{4: Completer(), 2: Completer()};
        final asked = <int>[];
        final repo = ServiceOrderRepoMock();
        when(() => repo.getList(any(), any(), page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
            .thenAnswer((inv) async {
          final page = inv.namedArguments[#page] as int;
          asked.add(page);
          await gates[page]?.future;
          // 25 linhas, tamanho 10 ⇒ 3 páginas; a 4 volta VAZIA com total 25
          final n = page <= 3 ? (page == 3 ? 5 : 10) : 0;
          return Right(PagedResult<ServiceOrderListItem>(
              items: [for (var i = 0; i < n; i++) ServiceOrderListItem(id: page * 100 + i, number: page * 100 + i, customerId: 1, status: 'A')],
              page: page,
              pageSize: 10,
              total: 25));
        });
        final bloc = buildServiceOrderBloc(repo: repo);
        final states = <ServiceOrderState>[];
        final sub = bloc.stream.listen(states.add);
        final errors = await _guarded(() async {
          bloc.add(const ServiceOrderListRequested(status: 'A', filter: '', page: 4));
          await pumpEventQueue(times: 20);
          bloc.add(const ServiceOrderListRequested(page: 2));
          await pumpEventQueue(times: 20);
          if (slowFirst) {
            gates[2]!.complete();
            await pumpEventQueue(times: 20);
            gates[4]!.complete();
          } else {
            gates[4]!.complete();
            await pumpEventQueue(times: 20);
            gates[2]!.complete();
          }
          await pumpEventQueue(times: 40);
        });
        final last = states.whereType<ServiceOrderListState>().last;
        await sub.cancel();
        await bloc.close();
        expect(errors, isEmpty);
        expect([last.page, last.loading, last.items.length, last.total], [2, false, 10, 25], reason: 'slowFirst=$slowFirst, GETs $asked');
      }
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------
  // 4. FISCAL_DPS_REJECTED nas formas do PRODUTOR (fiscal-api https-json.ts:259-266)
  // ---------------------------------------------------------------------------------------------------------------------------------
  group('(4) FISCAL_DPS_REJECTED × formas reais', () {
    testWidgets('[RESISTIU] 1 rejeição / 3 rejeições / "sem detalhar" / código sem texto / texto sem código / forma ANTIGA (`field` = o código) / `event`: '
        'uma linha "• …" por rejeição, nunca o nome técnico (`dps:`/`event:`), nunca linha duplicada de título', (tester) async {
      Future<List<String>> lines(List<FailureField> fields) async {
        final text = await _rejectionDialog(tester, fields);
        return text.split('\n').where((l) => l.startsWith('• ')).toList();
      }

      expect(await lines(const [FailureField(field: 'dps', message: 'E0116: Inscrição municipal do prestador obrigatória')]),
          ['• E0116: Inscrição municipal do prestador obrigatória']);
      expect(
          await lines(const [
            FailureField(field: 'dps', message: 'E0116: IM obrigatória'),
            FailureField(field: 'dps', message: 'E0840: Município inválido (cLocEmi)'),
            FailureField(field: 'dps', message: 'E0001: Falha genérica'),
          ]),
          ['• E0116: IM obrigatória', '• E0840: Município inválido (cLocEmi)', '• E0001: Falha genérica']);
      expect(await lines(const [FailureField(field: 'dps', message: 'Fisco recusou (400) sem detalhar')]), ['• Fisco recusou (400) sem detalhar']);
      expect(await lines(const [FailureField(field: 'dps', message: 'E0718: ')]), ['• E0718: ']);
      expect(await lines(const [FailureField(field: 'event', message: 'E1830: Evento fora do prazo')]), ['• E1830: Evento fora do prazo']);
      // a forma antiga (o `field` é o código E, a mensagem é o texto) segue com o código na frente
      expect(await lines(const [FailureField(field: 'E0116', message: 'Inscrição municipal obrigatória')]),
          ['• E0116: Inscrição municipal obrigatória']);
      // sem `field` nenhum
      expect(await lines(const [FailureField(field: '', message: 'E0116: IM')]), ['• E0116: IM']);
    });

    testWidgets('[CORRIGIDO LF-ADV-08] a rejeição de MENSAGEM VAZIA (`{field:"dps", message:""}` — o `authorityRejections` do produtor emite '
        '`message: ""` para um item `{}` ou `[1]` do fisco) já não vira a linha em branco "• ": as linhas sem texto saem e, quando TODAS saem, '
        'vale o `Failure.message` ("Fisco rejeitou (400): sem detalhe")', (tester) async {
      final text = await _rejectionDialog(tester, const [FailureField(field: 'dps', message: '')], message: 'Fisco rejeitou (400): sem detalhe');
      expect(text.split('\n').where((l) => l.startsWith('•')).toList(), isEmpty);
      expect(text, contains('sem detalhe'));
    });

    testWidgets('[RESISTIU] o `field` do produtor com variação de caixa/espaço NÃO existe (só `dps`/`event` minúsculos — rejectField fixo em adn.ts); '
        'a regra é por igualdade exata e o resto segue "campo: mensagem" (a forma antiga), sem perder a mensagem', (tester) async {
      final text = await _rejectionDialog(tester, const [FailureField(field: 'DPS', message: 'E0116: IM')]);
      expect(text, contains('• DPS: E0116: IM'));
    });
  });
}
