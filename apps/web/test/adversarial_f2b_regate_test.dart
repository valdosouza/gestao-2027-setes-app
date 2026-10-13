// RE-GATE ADVERSARIAL da F2b (setes-app como cliente DIRETO da nfse-api) —
// alvo: commit bbeb1d6 (delta sobre 289de28: D-F148…D-F150 + correções do gate
// 0,68). O atacante tenta quebrar o DELTA: o build de publicação
// (`build-web.ps1`), a limpeza da sessão com várias abas (AppWidget ×
// `ProductToken.lastExpired`), a releitura do plano antes do fisco (D-F149), o
// sinal de parada do lote, a aba do emissor pela nfse-api e a seção "No fisco".
//
// Convenção do gate (a mesma do gate anterior):
//   - `[ACHADO F2B-RG-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_f2b_regate_test.dart
//   - `[Q-F165-RG-NN — decisão]` = depende de decisão do Valdo (também pulado).
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail e clientes falsos. Os
// testes do `build-web.ps1` só PARSEIAM/avaliam a função de validação no
// Windows PowerShell 5.1 — nunca rodam o `flutter build`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:setes_web/app/app_widget.dart';
import 'package:setes_web/app/modules/establishment/data/datasource/establishment_issuer_datasource.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/presentation/widget/service_order_fiscal_section.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _orderId = 7374;
const _reason = 'Serviço não prestado no mês';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');
const _local = ServiceOrderInvoiceCancelResult(orderId: _orderId, invoiceNumber: '704', event: 3);
const _authorizedVoice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);
const _authorizedTx = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');
const _gateway504 = Failure(message: 'core.errors.generic', statusCode: 504);

// CORRIGIDOS na sessão (rodam sempre): RG-01 (o script com BOM), RG-02 (a regra do app + sem loopback na publicação), RG-03 (a sessão
// salva relida do armazenamento), RG-05 (a releitura confere a nota), RG-07 (envelope + falha do catálogo na aba do emissor).

/// O plano em que SÓ a NFS-e autorizada impede (a saga vai ao fisco — D-F149).
ServiceOrderCancelPlan _onlyAuthority({int orderId = _orderId, bool? cashierOpen, bool touchesCash = false}) =>
    ServiceOrderCancelPlan(orderId: orderId, fiscalRecord: true, touchesCash: touchesCash, cashierOpen: cashierOpen, blocks: const [
      CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
    ]);

/// Cliente falso da nfse-api para a aba do emissor: devolve SEMPRE [reply]
/// (o que o NfseApiClient entrega depois do envelope estrito — `ok: true`).
class _FixedEmitterClient extends NfseApiClient {
  _FixedEmitterClient(this.reply) : super(baseUrl: 'http://nfse');
  final Map<String, dynamic> reply;

  @override
  Future<Map<String, dynamic>> get(String path) async => reply;
  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async => reply;
  @override
  Future<Map<String, dynamic>> delete(String path) async => reply;
}

/// O mínimo que o AppWidget pede ao Modular no initState e no ouvinte da expiração.
class _SessionModule extends Module {
  _SessionModule(this.session);
  final ProductToken session;

  @override
  List<Bind> get binds => [
        Bind.instance<ProductToken>(session),
        Bind.instance<ApiClient>(ApiClient(baseUrl: 'http://erp', session: session)),
        Bind.instance<LocalPrefs>(LocalPrefs()),
      ];
}

/// Roda um script no Windows PowerShell 5.1 (o shell da casa) por
/// `-EncodedCommand` (UTF-16LE: o texto chega intacto, sem a página de código).
Future<String> _ps(String script) async {
  final bytes = <int>[];
  for (final unit in script.codeUnits) {
    bytes
      ..add(unit & 0xff)
      ..add(unit >> 8);
  }
  final r = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-EncodedCommand', base64Encode(bytes)]);
  return '${r.stdout}'.trim();
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
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
  });

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

  // ---------------------------------------------------------------------
  // 1. build-web.ps1 — o build de PUBLICAÇÃO (F2B-SOC-09/D-F146)
  // ---------------------------------------------------------------------
  group('build-web.ps1 (publicação no Plesk)', () {
    test('[CORRIGIDO F2B-RG-01 MEDIUM] o script PARSEIA no Windows PowerShell 5.1 — hoje: UTF-8 sem BOM, o "—" vira "â€”" e o byte 0x94 (= ”) FECHA a string da linha 18',
        () async {
      // o PS 5.1 lê .ps1 sem BOM pela página ANSI (Windows-1252); U+201D é aspa para o tokenizador.
      // Provado também executando: `powershell -File build-web.ps1 -ApiUrl x -NfseApiUrl y` → ParserError
      // na linha 18, exit 1 — o guarda de publicação nunca roda e o operador cai no `flutter build` à mão.
      final path = File('build-web.ps1').absolute.path.replaceAll("'", "''");
      final out = await _ps(r"$t = $null; $e = $null; "
          "[void][System.Management.Automation.Language.Parser]::ParseFile('$path', [ref]\$t, [ref]\$e); "
          r"'ERROS=' + $e.Count");
      expect(out, 'ERROS=0');
    }, skip: Platform.isWindows ? false : 'só no Windows');

    test('[CORRIGIDO F2B-RG-02 LOW] a validação do script = a do app (AppConfig.urlProblems) e, sendo PUBLICAÇÃO, recusa loopback',
        () async {
      final src = File('build-web.ps1').readAsStringSync(); // UTF-8 (o texto como foi escrito)
      final fn = RegExp(r'^function Test-ApiUrl[\s\S]*?^\}', multiLine: true).firstMatch(src)!.group(0)!;
      const cases = [
        'https://nfse.setes.com.br/?a=1', // o app RECUSA (consulta) → build gerado abre a tela de erro de configuração
        'https://nfse.setes.com.br/#x', // idem (fragmento)
        'http://localhost:3002', // publicação apontando para o localhost de cada usuário
        'http://127.0.0.1:3002',
      ];
      // pré-condição: o app recusa as duas primeiras na abertura
      expect(AppConfig.urlProblems('NFSE_API_URL', cases[0]), isNotEmpty);
      expect(AppConfig.urlProblems('NFSE_API_URL', cases[1]), isNotEmpty);
      final out = await _ps('$fn\n'
          "foreach (\$v in @(${cases.map((c) => "'$c'").join(', ')}, 'https://nfse.setes.com.br')) "
          r"{ try { Test-ApiUrl 'NFSE_API_URL' $v; $v + '|ACEITA' } catch { $v + '|RECUSA' } }");
      final verdict = {for (final l in LineSplitter.split(out)) l.split('|').first.trim(): l.split('|').last.trim()};
      expect(verdict['https://nfse.setes.com.br'], 'ACEITA', reason: 'sanidade');
      for (final c in cases) {
        expect(verdict[c], 'RECUSA', reason: c);
      }
    }, skip: Platform.isWindows ? false : 'só no Windows');
  });

  // ---------------------------------------------------------------------
  // 2. A expiração com várias abas (F2B-ADV-11 → AppWidget + lastExpired)
  // ---------------------------------------------------------------------
  group('AppWidget — limpar a sessão salva só se for a que expirou', () {
    Future<void> expireIn(WidgetTester tester, ProductToken session, String token) async {
      Modular.init(_SessionModule(session));
      addTearDown(() {
        try {
          Modular.destroy();
        } catch (_) {}
      });
      // initState liga o ouvinte e o confirmador; o build (sem EasyLocalization/ThemeCubit
      // neste módulo de prova) falha — irrelevante: o que se ataca é o ouvinte
      await tester.pumpWidget(const AppWidget());
      tester.takeException();
      // o ouvinte é async: as continuações dele ficam na zona guardada (o
      // Modular.to.navigate sem roteador pode lançar — irrelevante aqui)
      runZonedGuarded(() => session.expire(token), (_, __) {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // o timer do ModularRouterDelegate.navigate
    }

    testWidgets('[RESISTIU] UMA aba: a sessão salva que expirou é limpa (o refresh não restaura o token morto)', (tester) async {
      SharedPreferences.setMockInitialValues({'session_token': 'A'});
      final session = ProductToken()..value = 'A';
      await expireIn(tester, session, 'A');
      final store = await SharedPreferencesStorePlatform.instance.getAll();
      expect(store.containsKey('flutter.session_token'), isFalse);
    });

    testWidgets(
        '[CORRIGIDO F2B-RG-03 LOW] DUAS abas: a aba velha (token A) expira DEPOIS de a outra entrar de novo (B salvo) — o login novo tem de ficar no localStorage',
        (tester) async {
      SharedPreferences.setMockInitialValues({'session_token': 'A'});
      // esta aba abriu com A salvo: o SharedPreferences carrega o CACHE uma vez (getInstance)
      expect(await LocalPrefs().getSessionToken(), 'A');
      // a OUTRA aba saiu e entrou com "Manter conectado": escreve B direto no localStorage
      await SharedPreferencesStorePlatform.instance.setValue('String', 'flutter.session_token', 'B');
      final session = ProductToken()..value = 'A';
      await expireIn(tester, session, 'A');
      // hoje: app_widget.dart:40 lê o CACHE desta aba (A) == lastExpired (A) → remove → o B da outra aba some
      // (shared_preferences 2.5.5: getString lê `_preferenceCache`; `remove` vai ao localStorage) —
      // no F5 a outra aba cai no login. Correção: `SharedPreferences.reload()` antes de comparar.
      final store = await SharedPreferencesStorePlatform.instance.getAll();
      expect(store['flutter.session_token'], 'B');
    });
  });

  // ---------------------------------------------------------------------
  // 3. A releitura do plano antes do fisco (D-F149)
  // ---------------------------------------------------------------------
  group('saga — estágio `plan` (D-F149)', () {
    test('[CORRIGIDO F2B-RG-05 LOW] o plano relido de OUTRA nota (orderId ≠ o pedido) nunca autoriza ir ao fisco — a 1ª leitura (bloc) já confere desde o ADV-09',
        () async {
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => Right(_onlyAuthority(orderId: 9999)));
      when(() => nfse.cancel(any(), any()))
          .thenAnswer((_) async => const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId)));
      when(() => invoice.cancel(any(), any())).thenAnswer((_) async => const Right(_local));
      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);
      verifyNever(() => nfse.cancel(any(), any()));
      expect(r.fold((f) => f.stage, (_) => null), CancelSagaStage.plan);
    });

    test('[RESISTIU] caixa FECHADO na releitura (touchesCash + cashierOpen false): a saga não vai ao fisco', () async {
      when(() => invoice.cancelPlan(_orderId))
          .thenAnswer((_) async => Right(_onlyAuthority(touchesCash: true, cashierOpen: false)));
      final r = await ServiceOrderCancelInvoice(nfse: nfse, invoice: invoice)(_orderId, _reason, atAuthority: true);
      verifyNever(() => nfse.cancel(any(), any()));
      expect(r.fold((f) => [f.stage, f.failure.code], (_) => null), [CancelSagaStage.plan, FiscalCodes.cancelPlanChanged]);
    });

    test('[RESISTIU] a releitura cai no gateway (504 sem código): falha comum — NUNCA "desfecho desconhecido" (nada foi ao fisco)', () async {
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Left(_gateway504));
      final bloc = await opened();
      final states = await runDetail(bloc, const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      verifyNever(() => nfse.cancel(any(), any()));
      expect(states.whereType<ServiceOrderFiscalNotice>(), isEmpty, reason: '"consulte" mentiria: o fisco nem foi chamado');
      expect(states.whereType<ServiceOrderActionFailure>().single.failure, _gateway504);
    });

    test('[RESISTIU] o caixa fecha DEPOIS da releitura (a janela aceita da D-F149): o fisco cancela, o ERP recusa — "Aplicar o cancelamento na nota"',
        () async {
      when(() => nfse.cancel(_orderId, _reason))
          .thenAnswer((_) async => const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId)));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async =>
          const Left(Failure(message: 'Abra o caixa', statusCode: 409, code: 'NO_OPEN_CASHIER')));
      final states = await runDetail(
          await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalLocalCancelPending');
    });
  });

  test('[RESISTIU] LEITURA com 408/502/503/504 sem código (abrir a OS faturada): a seção diz "indisponível" — nunca o aviso de desfecho desconhecido (que é só de ATO)',
      () async {
    for (final status in [408, 502, 503, 504]) {
      final down = Failure(message: 'core.errors.generic', statusCode: status);
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => Left(down));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && s.fiscalFailure != null);
      bloc.add(const ServiceOrderViewRequested(_orderId));
      final detail = await shown as ServiceOrderDetailState;
      await sub.cancel();
      await bloc.close();
      expect(detail.fiscalFailure, down, reason: 'HTTP $status');
      expect(states.whereType<ServiceOrderFiscalNotice>(), isEmpty, reason: 'HTTP $status');
    }
  });

  // ---------------------------------------------------------------------
  // 4. O lote e o sinal de parada da página (F2B-ADV-03)
  // ---------------------------------------------------------------------
  group('lote — sinal de parada e D-F148', () {
    test('[RESISTIU] a parada da página com o bloc OCIOSO não vaza para o próximo lote (o flag zera no início)', () async {
      when(() => nfse.transmit(any())).thenAnswer((_) async => const Right(_authorizedTx));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      bloc.stopBatches(); // a tela saiu sem lote nenhum
      await pumpEventQueue();
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      final report = (await done as ServiceOrderFiscalBatchDone).report;
      await bloc.close();
      expect(report.transmitted, 2);
    });

    test('[RESISTIU] SESSION_NOT_ACCEPTED (D-F148) PARA o lote — vale para todas as notas', () async {
      when(() => nfse.transmit(any())).thenAnswer((_) async => const Left(Failure(
          message: 'core.errors.sessionNotAccepted', statusCode: 401, code: ClientFailureCodes.sessionNotAccepted)));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2, 3]));
      final report = (await done as ServiceOrderFiscalBatchDone).report;
      await bloc.close();
      verify(() => nfse.transmit(1)).called(1);
      verifyNever(() => nfse.transmit(2));
      expect(report.stoppedBy?.code, ClientFailureCodes.sessionNotAccepted);
    });
  });

  // ---------------------------------------------------------------------
  // 5. Aba "Emissor fiscal" pela nfse-api (envelope)
  // ---------------------------------------------------------------------
  group('aba "Emissor fiscal" — o envelope de dados', () {
    test('[CORRIGIDO F2B-RG-07 LOW] `{ ok: true }` sem `data` é falha técnica — hoje vira visão VAZIA (sem certificado; a SE renasce em "H" e salvar a série trocaria P → H, a classe do ADV-15)',
        () async {
      final ds = EstablishmentIssuerDatasourceImpl(client: _FixedEmitterClient(const {'ok': true}));
      await expectLater(ds.get(), throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.invalidResponse)));
      await expectLater(ds.removeCertificate(), throwsA(isA<Failure>()));
    });

    test('[CORRIGIDO F2B-RG-07 LOW] `data`/`issuers` de tipo trocado é Failure do catálogo — hoje é TypeError, que escapa do `on Failure` da seção (establishment_issuer_section.dart:129) e deixa o spinner para sempre',
        () async {
      for (final reply in const [
        {'ok': true, 'data': 'x'},
        {'ok': true, 'data': {'issuers': 'x'}},
      ]) {
        final ds = EstablishmentIssuerDatasourceImpl(client: _FixedEmitterClient(reply));
        await expectLater(ds.get(), throwsA(isA<Failure>()), reason: '$reply');
      }
    });
  });

  // ---------------------------------------------------------------------
  // 6. Seção "No fisco" (F2B-SOC-10/SOC-11, D-F150)
  // ---------------------------------------------------------------------
  group('seção "No fisco"', () {
    setUp(() => CurrentInterface.value =
        const MenuInterface(id: 1, description: 'service-orders', privileges: ['CANCELAR']));
    tearDown(() => CurrentInterface.value = null);

    Future<void> pump(WidgetTester tester, ServiceOrderDetailState state) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceOrderFiscalSection(
              state: state,
              onTransmit: () {},
              onFiscalRefresh: () {},
              onFiscalXml: () {},
              onFiscalDanfse: () {},
              onCancelInvoice: () {},
              onKeepInvoice: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('[RESISTIU] voz indisponível + efeito `apply`: "Aplicar o cancelamento na nota" aparece (depende só do ERP); o código de suporte do 503 chega à tela',
        (tester) async {
      await pump(tester, const ServiceOrderDetailState(
        order: _order,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503, supportRef: 'A1B2C3D4'),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.apply),
      ));
      expect(find.text('Aplicar o cancelamento na nota'), findsOneWidget);
      expect(find.textContaining('A1B2C3D4'), findsOneWidget);
    });

    testWidgets('[RESISTIU] sem TRANSMITIR: nem "Transmitir" nem "Consultar" (a nfse-api exige TRANSMITIR na consulta ativa)', (tester) async {
      await pump(tester, const ServiceOrderDetailState(
        order: _order,
        fiscal: ServiceOrderFiscalView(state: NfseState.failed, currentAttempt: 1, transmissions: [
          ServiceOrderFiscalTransmission(attempt: 1, environment: 'P', lastKind: 'F'),
        ]),
        effect: ServiceOrderFiscalEffect(),
      ));
      expect(find.text('Transmitir'), findsNothing);
      expect(find.text('Consultar'), findsNothing);
    });

    testWidgets('[DECIDIDO D-F159 (= Q-F167 (b))] voz indisponível + efeito `decide`: "Manter a nota" vem COM a linha do ERP que diz por quê (a substituição só vinha da voz)',
        (tester) async {
      await pump(tester, const ServiceOrderDetailState(
        order: _order,
        fiscalFailure: Failure(message: 'Fisco indisponível', statusCode: 503),
        effect: ServiceOrderFiscalEffect(effect: FiscalEffect.decide),
      ));
      // hoje: o botão aparece (service_order_fiscal_section.dart:303 — só o efeito) e a única frase da
      // substituição (fiscalSubstitutedRow) depende de `view.substitution` (:212) — botão de decisão sem contexto
      expect(find.text('Manter a nota'), findsOneWidget);
      expect(find.textContaining('SUBSTITUÍDA no fisco (segundo o sistema'), findsOneWidget);
    });
  });
}
