// GATE ADVERSARIAL da F2b (setes-app como cliente DIRETO da nfse-api —
// D-F4/D-F137…D-F147, `prompt_apis_fiscais_isoladas.md` §22.14/§22.16.3).
// Alvo: commit 289de28 (base f3f8abf). O atacante tenta quebrar a entrega com
// respostas hostis/tortas dos DOIS servidores, a saga do cancelamento, o lote
// "Transmitir notas sem NFS-e", a injeção das duas APIs e a aba do emissor.
//
// Convenção do gate:
//   - `[ACHADO F2B-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_f2b_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail e clientes falsos.
//
// CORRIGIDOS na sessão (rodam sempre — `[CORRIGIDO …]`): ADV-01 (408/502/503/504 sem código = desfecho desconhecido), ADV-02 (erro
// sistêmico de credencial/cadastro para o lote), ADV-03 (a tela que sai PARA o lote — stopBatches() no onDispose do módulo
// — D-F156; só nele desde a D-F160), ADV-04 (envelope estrito), ADV-05 (fotografia com garantia de progresso), ADV-07 (Transmitir com trava),
// ADV-08 (ordem dos avisos), ADV-09 (barreira desconhecida + id pedido), ADV-12 (tipo trocado = falha do catálogo / desconhecido no ato),
// ADV-13 (clientes IRMÃOS), ADV-15 (ambiente desconhecido neutro). Ficam PULADOS só os que dependem de decisão: o 500 como desfecho
// desconhecido (Q-F163) e o fechamento do bloc pelo Modular (Q-F164).

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
import 'package:setes_web/app/app_module.dart';
import 'package:setes_web/app/modules/establishment/data/datasource/establishment_issuer_datasource.dart';
import 'package:setes_web/app/modules/establishment/domain/entity/establishment_issuer_entity.dart';
import 'package:setes_web/app/modules/establishment/presentation/widget/establishment_issuer_section.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_invoice_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_nfse_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_nfse_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_pending.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/modules/service_orders/service_orders_module.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

import 'support/service_order_bloc_factory.dart';

const _orderId = 7374;
const _reason = 'Serviço não prestado no mês';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');
const _local = ServiceOrderInvoiceCancelResult(orderId: _orderId, invoiceNumber: '704', event: 3);
const _authorizedVoice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);
const _authorized = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');

/// O que um gateway (nginx/Plesk) devolve quando o fisco demora mais que o
/// `proxy_read_timeout` — corpo HTML, sem o envelope da casa (o ApiClient
/// monta Failure com o status e SEM code).
const _gateway504 = Failure(message: 'core.errors.generic', statusCode: 504);


/// O plano em que SÓ a NFS-e autorizada impede (a saga relê antes do fisco — D-F149).
const _onlyAuthority = ServiceOrderCancelPlan(orderId: _orderId, fiscalRecord: true, blocks: [
  CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
]);

/// Cliente falso da nfse-api: devolve SEMPRE [reply] (o que o ApiClient
/// entrega ao datasource depois de decodificar a resposta).
class _FixedNfseClient extends NfseApiClient {
  _FixedNfseClient(this.reply);
  final Map<String, dynamic> reply;

  @override
  Future<Map<String, dynamic>> get(String path) async => reply;

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? overrideToken}) async => reply;
}

/// Cliente falso do setes-api (mesma ideia).
class _FixedErpClient extends ApiClient {
  _FixedErpClient(this.reply);
  final Map<String, dynamic> reply;

  @override
  Future<Map<String, dynamic>> get(String path) async => reply;
}

/// Módulo de prova com a MESMA forma do bind do ServiceOrdersModule — D-F156:
/// `Bind.singleton<ServiceOrderBloc>` COM `onDispose: close` (o teste ao lado
/// confere que o módulo real tem o `onDispose`).
class _BlocModule extends Module {
  _BlocModule(this.make);
  final ServiceOrderBloc Function() make;

  @override
  List<Bind> get binds => [
        Bind.singleton<ServiceOrderBloc>((_) => make(), onDispose: (bloc) {
          bloc.stopBatches();
          bloc.close();
        }),
      ];
}

/// O AppModule com os dois clientes em ORDEM TROCADA (refatoração inocente).
class _ReorderedClientsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.singleton<ProductToken>((_) => ProductToken()),
        Bind.singleton<NfseApiClient>((i) => NfseApiClient(baseUrl: 'http://nfse', session: i.get<ProductToken>())),
        Bind.singleton<ApiClient>((i) => ApiClient(baseUrl: 'http://erp', session: i.get<ProductToken>())),
      ];
}

/// Datasource falso do emissor (só o GET importa aqui).
class _IssuerDs implements EstablishmentIssuerDatasource {
  _IssuerDs(this.view);
  final EstablishmentIssuerView view;

  @override
  Future<EstablishmentIssuerView> get() async => view;
  @override
  Future<EstablishmentIssuerView> saveIssuer(String model, {required String environment, required String serie}) async => view;
  @override
  Future<void> removeIssuer(String model) async {}
  @override
  Future<IssuerCertStatus> saveCertificate({required String pfxBase64, required String password}) async =>
      view.certificate;
  @override
  Future<IssuerCertStatus> removeCertificate() async => view.certificate;
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
    when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Right(_onlyAuthority));
  });

  /// Bloc com a OS faturada aberta no detalhe.
  Future<ServiceOrderBloc> opened() async {
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState);
    bloc.add(const ServiceOrderViewRequested(_orderId));
    await shown;
    return bloc;
  }

  /// Dispara [event] no detalhe e coleta os estados até o detalhe voltar.
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

  List<int> transmitidas() => verify(() => nfse.transmit(captureAny())).captured.cast<int>();

  // ---------------------------------------------------------------------
  // 1. Respostas hostis/tortas dos dois servidores
  // ---------------------------------------------------------------------
  group('respostas tortas — o que o app inventa quando o dado não vem', () {
    test('[CORRIGIDO F2B-ADV-04 MEDIUM] visão SEM envelope ({} — 200 HTML do host errado) deveria falhar',
        () async {
      final ds = ServiceOrderNfseDatasourceImpl(client: _FixedNfseClient(const {}));
      await expectLater(ds.getView(_orderId), throwsA(isA<Failure>()));
    });

    test('[CORRIGIDO F2B-ADV-04 MEDIUM] pendentes SEM envelope deveriam falhar',
        () async {
      final ds = ServiceOrderNfseDatasourceImpl(client: _FixedNfseClient(const {}));
      await expectLater(ds.pending(), throwsA(isA<Failure>()));
    });

    test('[CORRIGIDO F2B-ADV-04 MEDIUM] transmit 2xx SEM envelope deveria ser desfecho desconhecido',
        () async {
      final repository = ServiceOrderNfseRepositoryImpl(
          datasource: ServiceOrderNfseDatasourceImpl(client: _FixedNfseClient(const {})));
      final r = await repository.transmit(_orderId);
      expect(r.fold(isUnknownAuthorityOutcome, (_) => false), isTrue);
    });

    test('[CORRIGIDO F2B-ADV-04 MEDIUM] cancelamento NO FISCO 2xx sem envelope deveria parar a saga',
        () async {
      final ds = ServiceOrderNfseDatasourceImpl(client: _FixedNfseClient(const {}));
      await expectLater(ds.cancel(_orderId, _reason), throwsA(isA<Failure>()));
    });

    test('[RESISTIU — mais estrito depois do ADV-04] efeito do ERP SEM envelope é FALHA técnica (a seção diz "efeito indisponível") — nunca "nada a fazer"; efeito desconhecido segue neutro', () async {
      final ds = ServiceOrderInvoiceDatasourceImpl(client: _FixedErpClient(const {}));
      await expectLater(ds.fiscalEffect(_orderId), throwsA(isA<Failure>().having((f) => f.code, 'code', ClientFailureCodes.invalidResponse)));
      expect(ServiceOrderFiscalEffect.fromJson(const {'effect': 'apply-v2'}).effect, FiscalEffect.unknown);
      expect(ServiceOrderFiscalEffect.fromJson(const {'effect': 7, 'cancelWaiver': 'x'}).cancelWaiver, isNull);
    });

    test('[RESISTIU] state desconhecido não oferece Transmitir; kind de barreira desconhecido é "unknown" (sem ação)', () {
      final view = ServiceOrderFiscalView.fromJson(const {'state': 'authorized_v2', 'currentAttempt': 1});
      expect(view.canTransmitState, isFalse);
      expect(view.state == NfseState.authorized, isFalse, reason: 'o botão "Cancelar NFS-e" não aparece');
      expect(FiscalBarrier.fromJson(const {'kind': 'authorised'}).kind, FiscalBarrierKind.unknown);
      expect(FiscalBarrier.fromJson(const {'kind': null}).kind, FiscalBarrierKind.unknown);
    });

    test('[RESISTIU] currentAttempt que NÃO existe na lista não "escolhe" a última tentativa', () {
      final view = ServiceOrderFiscalView.fromJson(const {
        'state': 'authorized',
        'currentAttempt': 9,
        'transmissions': [
          {'attempt': 1, 'lastKind': 'R'},
          {'attempt': 2, 'lastKind': 'A', 'accessKey': 'CHAVE-2'},
        ],
      });
      expect(view.current, isNull);
    });

    test('[RESISTIU] blocos opcionais com tipo trocado viram ausência (substitution/cancelWaiver/barrier não-objeto)', () {
      expect(ServiceOrderFiscalView.fromJson(const {'state': 'cancelled', 'substitution': 'sim'}).isSubstituted, isFalse);
      expect(CancelPlanBlock.fromJson(const {'field': 'fiscal', 'message': 'x', 'barrier': 'authorized'}).barrier, isNull);
    });

    test('[CORRIGIDO F2B-ADV-12 LOW] linha nula numa lista da visão vira Failure do CATÁLOGO (core.errors.*), o texto cru só no supportRef', () async {
      final repository = ServiceOrderNfseRepositoryImpl(
          datasource: ServiceOrderNfseDatasourceImpl(
              client: _FixedNfseClient(const {
        'ok': true,
        'data': {'state': 'authorized', 'transmissions': [null]},
      })));
      final failure = (await repository.getView(_orderId)).fold((f) => f, (_) => null);
      expect(failure, isNotNull);
      // certo: falha técnica com mensagem do catálogo (core.errors.*) — hoje
      // "type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast"
      expect(failure!.message, startsWith('core.errors.'));
    });

    test('[CORRIGIDO F2B-ADV-12 LOW] transmit 201 com corpo torto (data lista) é desfecho DESCONHECIDO (nunca "recusada" no lote)',
        () async {
      final repository = ServiceOrderNfseRepositoryImpl(
          datasource: ServiceOrderNfseDatasourceImpl(
              client: _FixedNfseClient(const {
        'ok': true,
        'data': ['A', 'CHAVE'],
      })));
      final r = await ServiceOrderFiscalTransmitBatch(repository: repository)([_orderId]);
      expect(r.rows.single.ok, isFalse);
      expect(isUnknownAuthorityOutcome(Failure(message: r.rows.single.message, code: r.rows.single.code)), isTrue,
          reason: 'o fisco respondeu 201 — a NFS-e existe; "recusada" engana o operador');
    });
  });

  // ---------------------------------------------------------------------
  // 2. Desfecho desconhecido × gateway (F2B-ADV-01)
  // ---------------------------------------------------------------------
  group('F2B-ADV-01 — 502/503/504 SEM o código da nfse-api (gateway)', () {
    test('[CORRIGIDO F2B-ADV-01 MEDIUM] o classificador trata 408/502/503/504 SEM código (gateway) como desfecho DESCONHECIDO; com código da casa segue a regra do código', () {
      for (final status in [408, 502, 503, 504]) {
        expect(isUnknownAuthorityOutcome(Failure(message: 'core.errors.generic', statusCode: status)), isTrue,
            reason: 'HTTP $status sem code — a tentativa pode estar em voo na nfse-api');
      }
      expect(isUnknownAuthorityOutcome(const Failure(message: 'x', statusCode: 503, code: 'FISCAL_MASTER_KEY_UNAVAILABLE')), isFalse);
      // D-F163 (= Q-F171 (a)): a contenção num ATO pode vir DEPOIS do fisco — desconhecido
      expect(isUnknownAuthorityOutcome(const Failure(message: 'x', statusCode: 409, code: FiscalCodes.resourceBusy)), isTrue);
    });

    test('[DECIDIDO D-F155 (= Q-F163 (a))] o 500 da nfse-api num ATO (INTERNAL ou sem código) é desfecho desconhecido — nada garante que o ato não aconteceu', () {
      expect(isUnknownAuthorityOutcome(const Failure(message: 'core.errors.generic', statusCode: 500)), isTrue);
      expect(isUnknownAuthorityOutcome(const Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL')), isTrue);
      expect(isUnknownAuthorityOutcome(const Failure(message: 'x', statusCode: 500, code: 'OUTRO_CODIGO')), isFalse);
    });

    test('[CORRIGIDO F2B-ADV-01 MEDIUM] Transmitir com 504 do gateway diz "resultado incerto — consulte" (nunca falha seca)',
        () async {
      when(() => nfse.transmit(_orderId)).thenAnswer((_) async => const Left(_gateway504));
      final states = await runDetail(await opened(), const ServiceOrderTransmitRequested(_orderId));
      expect(states.whereType<ServiceOrderFiscalNotice>().map((n) => n.messageKey),
          contains('forms.serviceOrder.fiscalOutcomeUnknown'));
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
    });

    test('[CORRIGIDO F2B-ADV-01 MEDIUM] saga: cancelamento no fisco com 504 do gateway é "consulte"',
        () async {
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(_gateway504));
      final states = await runDetail(
          await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(states.whereType<ServiceOrderFiscalNotice>().map((n) => n.messageKey),
          contains('forms.serviceOrder.fiscalOutcomeUnknown'));
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('[RESISTIU] saga: 504 do gateway no fisco também NUNCA chega ao ERP (D-F28)', () async {
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(_gateway504));
      await runDetail(
          await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('[CORRIGIDO F2B-ADV-01 MEDIUM] lote: 3 x 504 do gateway SEGUIDOS PARAM o lote (o fisco lento não se insiste nota a nota)',
        () async {
      when(() => nfse.transmit(any())).thenAnswer((_) async => const Left(_gateway504));
      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)([1, 2, 3, 4, 5, 6]);
      expect(transmitidas(), [1, 2, 3]);
      expect(r.stoppedBy, isNotNull);
    });
  });

  // ---------------------------------------------------------------------
  // 3. Lote — erro sistêmico, teto, ids, paginação
  // ---------------------------------------------------------------------
  group('lote "Transmitir notas sem NFS-e" (D-F145)', () {
    final credencial = <String, Failure>{
      'fisco recusou o certificado (mTLS/401/403 no fisco)': const Failure(
          message: 'Fisco recusou a autenticação (403)', statusCode: 409, code: 'FISCAL_AUTHORITY_AUTH_FAILED'),
      'cadeia TLS do fisco não confiável': const Failure(
          message: 'Certificado do servidor do fisco não confiável', statusCode: 409, code: 'FISCAL_AUTHORITY_CHAIN_UNTRUSTED'),
      'cadastro do ESTABELECIMENTO incompleto': const Failure(
          message: 'Cadastro do estabelecimento incompleto', statusCode: 422, code: 'FISCAL_EMITTER_INCOMPLETE'),
    };
    for (final e in credencial.entries) {
      test('[CORRIGIDO F2B-ADV-02 MEDIUM] ${e.key} vale para TODAS as notas → PARA o lote', () async {
        when(() => nfse.transmit(any())).thenAnswer((_) async => Left(e.value));
        final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)([1, 2, 3, 4]);
        expect(transmitidas(), [1], reason: 'hoje são 4 tentativas — "tente de novo só empilha tentativas" (https-json.ts)');
        expect(r.stoppedBy, e.value);
      });
    }

    test('[RESISTIU] 401 no meio para o lote e o resto entra como "não tentada"; ids repetidos contam uma vez', () async {
      when(() => nfse.transmit(any())).thenAnswer(
          (inv) async => inv.positionalArguments[0] == 2 ? const Left(UnauthorizedFailure()) : const Right(_authorized));
      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)([1, 2, 2, 3, 1, 4]);
      expect(transmitidas(), [1, 2]);
      expect(r.rows.map((x) => x.orderId), [1, 2, 3, 4]);
      expect(r.rows.skip(2).every((x) => x.code == FiscalTransmitBatchRow.abortedCode), isTrue);
    });

    test('[RESISTIU] rede caída 3 vezes seguidas para o lote (NetworkFailure = desconhecido)', () async {
      when(() => nfse.transmit(any())).thenAnswer((_) async => const Left(NetworkFailure()));
      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)([1, 2, 3, 4, 5]);
      expect(transmitidas(), [1, 2, 3]);
      expect(r.stoppedBy, isA<NetworkFailure>());
    });

    test('[RESISTIU] teto de 500: páginas sem fim de notas NOVAS param em fiscalBatchMaxNotes', () async {
      var calls = 0;
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((inv) async {
        calls++;
        final page = inv.namedArguments[#page] as int;
        return Right(PagedResult(
            items: [for (var k = 0; k < 100; k++) ServiceOrderFiscalPending(invoiceId: page * 1000 + k)],
            page: page, pageSize: 100, total: 1 << 30));
      });
      final r = await ServiceOrderFiscalPendingList(repository: nfse)();
      expect(r.getOrElse(() => []).length, fiscalBatchMaxNotes);
      expect(calls, 5);
    });

    test('[CORRIGIDO F2B-ADV-05 LOW] total MENTIROSO + a MESMA página de volta (servidor ignora `page`) PARA — página sem nota nova encerra',
        () async {
      var calls = 0;
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((inv) async {
        calls++;
        final page = inv.namedArguments[#page] as int;
        if (page > 60) return const Right(PagedResult.empty()); // freio do TESTE — no app não existe
        return Right(PagedResult(
            items: [for (var k = 1; k <= 100; k++) ServiceOrderFiscalPending(invoiceId: k)],
            page: 1, pageSize: 100, total: 1000000000));
      });
      await ServiceOrderFiscalPendingList(repository: nfse)();
      // certo: página sem NENHUMA nota nova encerra a fotografia (ou teto de
      // páginas = ceil(500/100)+1) — hoje seriam 10.000.000 de GETs
      expect(calls, lessThanOrEqualTo(6));
    });
  });

  // ---------------------------------------------------------------------
  // 4. Tela fechada no meio (F2B-ADV-03) — o bloc nunca é fechado em produção
  // ---------------------------------------------------------------------
  group('F2B-ADV-03 — "tela fechada para o lote" (D-F145)', () {
    test('[CORRIGIDO F2B-ADV-03 MEDIUM] a tela que SAI manda parar: depois da nota em voo o lote não segue (bloc não fechado — o Modular não o fecha)', () async {
      final gates = <Completer<void>>[];
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return const Right(_authorized);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2, 3]));
      await pumpEventQueue();
      expect(gates, hasLength(1), reason: 'a 1ª nota está "no fisco"');
      bloc.stopBatches(); // o onDispose do módulo (D-F160)
      await pumpEventQueue();
      for (var k = 0; k < 6; k++) {
        for (final g in gates.where((g) => !g.isCompleted)) {
          g.complete();
        }
        await pumpEventQueue();
      }
      expect(transmitidas(), [1], reason: 'a nota em voo termina; as seguintes não são tentadas');
      expect(states.whereType<ServiceOrderFiscalBatchDone>(), isEmpty, reason: 'tela fechada = sem relatório (D-F145)');
      await sub.cancel();
      await bloc.close();
    });

    test('[DECIDIDO D-F160 (= Q-F168 (a))] o sinal de parada é SÓ do onDispose do módulo — o dispose da página (que roda também na troca de layout ao cruzar 1100 px) não para o lote (cerca no fonte)', () {
      final src = File('lib/app/modules/service_orders/presentation/page/service_order_page.dart').readAsStringSync();
      final dispose = RegExp(r'void dispose\(\) \{[\s\S]*?super\.dispose\(\);').firstMatch(src)!.group(0)!;
      expect(dispose, isNot(contains('stopBatches')));
      final module = File('lib/app/modules/service_orders/service_orders_module.dart').readAsStringSync();
      expect(module, matches(RegExp(r'onDispose: \(bloc\) \{\s*bloc\.stopBatches\(\);\s*bloc\.close\(\);')));
    });

    test('[DECIDIDO D-F156 (= Q-F164 (a))] o bind do ServiceOrderBloc fecha o bloc quando o módulo é desmontado (corta também o lote de faturamento — Q-R5.2)', () {
      final bind = ServiceOrdersModule().binds.whereType<Bind<ServiceOrderBloc>>().single;
      // o Modular 5 só "descarta" valor `Disposable` ou com `onDispose`; o Bloc
      // não é Disposable (modular_core bind_context.dart `_executeDisposeImplementation`)
      expect(bind.onDispose, isNotNull);
    });

    test('[DECIDIDO D-F156] módulo desmontado SEM a página (o Modular sozinho) também pararia o lote se o bloc fosse fechado',
        () async {
      final gates = <Completer<void>>[];
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return const Right(_authorized);
      });
      Modular.init(_BlocModule(() => buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice)));
      try {
        final bloc = Modular.get<ServiceOrderBloc>();
        bloc.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2, 3]));
        await pumpEventQueue();
        expect(gates, hasLength(1), reason: 'a 1ª nota está "no fisco"');
        Modular.destroy(); // o usuário saiu da tela: o Modular desmonta o módulo
        for (var k = 0; k < 6; k++) {
          for (final g in gates.where((g) => !g.isCompleted)) {
            g.complete();
          }
          await pumpEventQueue();
        }
        expect(transmitidas(), [1], reason: 'o lote seguiu no bloc órfão depois que a tela saiu');
        expect(bloc.isClosed, isTrue);
      } finally {
        try {
          Modular.destroy();
        } catch (_) {}
      }
    });
  });

  // ---------------------------------------------------------------------
  // 5. Saga do cancelamento (D-F139)
  // ---------------------------------------------------------------------
  group('saga do cancelamento', () {
    test('[RESISTIU] bloc fechado NO MEIO da saga: o passo do ERP ainda acontece depois do fisco (sem exceção)', () async {
      final gate = Completer<void>();
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async {
        await gate.future;
        return const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId));
      });
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_local));
      final bloc = await opened();
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      await pumpEventQueue();
      await bloc.close();
      gate.complete();
      await pumpEventQueue();
      verify(() => invoice.cancel(_orderId, _reason)).called(1);
    });

    test('[RESISTIU] "manter a nota" disparado durante a saga é IGNORADO (decisões exclusivas sobre a mesma nota)', () async {
      final gate = Completer<void>();
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async {
        await gate.future;
        return const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId));
      });
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Right(_local));
      final bloc = await opened();
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && !s.saving);
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      await pumpEventQueue();
      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(orderId: _orderId, reason: _reason));
      await pumpEventQueue();
      gate.complete();
      await done;
      await bloc.close();
      verifyNever(() => invoice.cancelWaiver(any(), any()));
    });

    test('[RESISTIU] o plano mudou entre a leitura e o POST (sem barreira na tela, NFS-e autorizada agora): o ERP recusa e a tela relê — o fisco nem é chamado',
        () async {
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(Failure(
          message: 'Nota bloqueada', statusCode: 409, code: FiscalCodes.invoiceCancelBlocked,
          fields: [FailureField(field: 'fiscal', message: 'NFS-e autorizada — cancele no fisco primeiro')])));
      final states = await runDetail(
          await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: false));
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.code, FiscalCodes.invoiceCancelBlocked);
      verifyNever(() => nfse.cancel(any(), any()));
      verify(() => repo.getById(_orderId)).called(2);
    });

    test('[RESISTIU] o fisco cancelou e a nota caiu por 401 (sessão expirou entre os dois): authorityCancelled — a retomada é por derivação',
        () async {
      when(() => nfse.cancel(_orderId, _reason))
          .thenAnswer((_) async => const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId)));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(UnauthorizedFailure()));
      final states = await runDetail(
          await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalLocalCancelPending');
    });

    test('[CORRIGIDO F2B-ADV-08 LOW] fisco já tinha cancelado (voz C pré-existente) e a nota JÁ estava cancelada: o aviso é "a situação mudou"',
        () async {
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer(
          (_) async => const Right(ServiceOrderFiscalCancelResult(invoiceId: _orderId, atAuthority: false)));
      when(() => invoice.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(
          Failure(message: 'Nota já cancelada', statusCode: 409, code: FiscalCodes.invoiceNotCancellable)));
      final states = await runDetail(
          await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalSituationChanged');
    });

    test('[CORRIGIDO F2B-ADV-09 LOW] bloco `fiscal` SEM barreira tipada (ou barreira não-objeto) é barreira DESCONHECIDA (nunca "o fisco não barra")',
        () {
      final plan = ServiceOrderCancelPlan.fromJson(const {
        'orderId': _orderId,
        'cancellable': false,
        'blocks': [
          {'field': 'fiscal', 'message': 'NFS-e autorizada no fisco — cancele no fisco primeiro'},
        ],
      });
      expect(plan.localBlocks, isEmpty);
      // service_order_page.dart:600-606: barrier == null → motivo → cancelar a
      // nota (atAuthority: false) — a página nem olha `cancellable`
      expect(plan.fiscalBarrier?.kind, FiscalBarrierKind.unknown);
    });

    test('[CORRIGIDO F2B-ADV-09 LOW] plano SEM `orderId`: o one-shot carrega o id PEDIDO',
        () async {
      when(() => invoice.cancelPlan(_orderId))
          .thenAnswer((_) async => Right(ServiceOrderCancelPlan.fromJson(const {'cancellable': true, 'blocks': []})));
      final bloc = await opened();
      final ready = bloc.stream.firstWhere((s) => s is ServiceOrderCancelPlanReady);
      bloc.add(const ServiceOrderCancelFlowRequested(_orderId));
      final plan = (await ready as ServiceOrderCancelPlanReady).plan;
      await bloc.close();
      expect(plan.orderId, _orderId, reason: 'a saga iria para /v1/nfse/invoices/0 e /api/billing/cancel {orderId: 0}');
    });
  });

  // ---------------------------------------------------------------------
  // 6. Transmitir duas vezes (F2B-ADV-07)
  // ---------------------------------------------------------------------
  test('[CORRIGIDO F2B-ADV-07 LOW] dois "Transmitir" seguidos disparam UM envio',
      () async {
    final gate = Completer<void>();
    when(() => nfse.transmit(_orderId)).thenAnswer((_) async {
      await gate.future;
      return const Right(_authorized);
    });
    final bloc = await opened();
    bloc.add(const ServiceOrderTransmitRequested(_orderId));
    await pumpEventQueue();
    bloc.add(const ServiceOrderTransmitRequested(_orderId));
    await pumpEventQueue();
    gate.complete();
    await pumpEventQueue();
    await bloc.close();
    verify(() => nfse.transmit(_orderId)).called(1);
  });

  // ---------------------------------------------------------------------
  // 7. Duas APIs na injeção (D-F4/D-F138) — F2B-ADV-13
  // ---------------------------------------------------------------------
  group('injeção das duas APIs', () {
    test('[RESISTIU] AppModule real: get<ApiClient> é o do setes-api, get<NfseApiClient> o da nfse-api, UM ProductToken', () {
      Modular.init(AppModule());
      try {
        final erp = Modular.get<ApiClient>();
        final fiscal = Modular.get<NfseApiClient>();
        expect(erp, isNot(isA<NfseApiClient>()));
        expect(erp.baseUrl, AppConfig.baseApiUrl);
        expect(fiscal.baseUrl, AppConfig.nfseApiUrl);
        expect(identical(erp.session, fiscal.session), isTrue);
      } finally {
        Modular.destroy();
      }
    });

    test('[CORRIGIDO F2B-ADV-13 LOW] a separação vale por TIPO (clientes IRMÃOS): com os binds em ordem trocada, get<ApiClient> segue sendo o do setes-api — e o compilador já não aceita o cliente da nfse-api no datasource do ERP',
        () {
      expect(NfseApiClient(baseUrl: 'http://nfse'), isNot(isA<ApiClient>()));
      Modular.init(_ReorderedClientsModule());
      try {
        expect(Modular.get<ApiClient>().baseUrl, 'http://erp');
        expect(Modular.get<NfseApiClient>().baseUrl, 'http://nfse');
      } finally {
        Modular.destroy();
      }
    });
  });

  // ---------------------------------------------------------------------
  // 8. Aba do emissor (D-F137)
  // ---------------------------------------------------------------------
  group('aba "Emissor fiscal" pela nfse-api', () {
    test('[RESISTIU] série fora da faixa / torta é recusada ANTES da API (mesma regra do DTO)', () {
      for (final s in ['0', '00000', '50000', '99999', '123456', '1a', '', ' ', '-1', '1.0', '١٢']) {
        expect(issuerSerieValid(s), isFalse, reason: '"$s"');
      }
      for (final s in ['1', '00001', ' 49999 ', '900']) {
        expect(issuerSerieValid(s), isTrue, reason: '"$s"');
      }
    });

    test('[RESISTIU] cutoverAt nulo = "Aguardando a migração"; o 55 que vier da API não entra na aba', () {
      final view = EstablishmentIssuerView.fromJson(const {
        'issuers': [
          {'model': 'SE', 'environment': 'P', 'serie': '1', 'enabled': false, 'authority': 'ADN', 'cutoverAt': null},
          {'model': '55', 'environment': 'P', 'serie': '1', 'enabled': true, 'authority': 'SEFAZ'},
          'lixo',
        ],
        'certificate': {'certificate': true, 'privateKey': true},
      });
      expect(view.badgeFor('SE'), IssuerBadge.awaitingCutover);
      expect(kIssuerModels, ['SE']);
    });

    test('[CORRIGIDO F2B-ADV-15 LOW] ambiente AUSENTE na resposta não vira "H" (salvar a série trocaria P → H calado)', () {
      final issuer = EstablishmentIssuer.fromJson(const {'model': 'SE', 'serie': '7', 'cutoverAt': '2026-11-20 00:00:00'});
      expect(issuer.environment, isNot('H'));
    });

    testWidgets('[CORRIGIDO F2B-ADV-15 LOW] ambiente DESCONHECIDO vindo da API não derruba a aba (sem seleção inventada)',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ds = _IssuerDs(const EstablishmentIssuerView(
        issuers: [EstablishmentIssuer(model: 'SE', environment: 'X', serie: '1', authority: 'ADN')],
      ));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EstablishmentIssuerSection(datasource: ds, pickPfx: () async => null),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
