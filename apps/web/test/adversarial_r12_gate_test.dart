// GATE ADVERSARIAL independente do DELTA (correções dos gates da Rodada 11 +
// Rodada 12) da F2a/F2b (setes-app) — alvo: `5983b29..495267b` (branch f2b):
// `ClientFailureCodes.all` + cerca (R11-SOC-04); D-F182 (`_rereadAfterAct` relê
// a OS do ato ou a MESMA OS reaberta; `_outcomeOrder` põe o número da OS nos
// one-shots quando a tela é outra OS ou a lista; a página prefixa "OS N: " pela
// ponte com `about`); D-F183 (travas de duplo clique POR NOTA); D-F184
// (`_dispatch` — a decisão do diálogo vai ao bloc se ELE está vivo); D-F185 (o
// repositório da nfse-api troca a mensagem da `NetworkFailure` pela frase neutra).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R12-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r12_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre) — cada ACHADO
//     tem o seu FATO, que é a PROVA executável de hoje.
//   - `[CERCA …]` = a proteção que falta, escrita como teste que roda sempre.
// Nada aqui fala com servidor: repositórios mocktail (molde dos gates R9–R11).
// O lado nfse-api deste gate: `nfse-api/src/__tests__/adversarial-f2a-r12-gate.test.ts`.

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
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/establishment/data/datasource/establishment_issuer_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_invoice_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_nfse_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_invoice_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_nfse_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_cancel_invoice.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

/// A OS NOVA (aberta) e duas OS FATURADAS — a voz de A muda quando um ato dela termina.
const _newId = 77;
const _newOrder = ServiceOrderFull(id: _newId, customerId: 5);
const _aId = 7374;
const _a = ServiceOrderFull(id: _aId, customerId: 1, status: 'F');
const _bId = 8001;
const _b = ServiceOrderFull(id: _bId, customerId: 2, status: 'F');
const _before = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
const _after = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 2);
const _bVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 3);
const _aEffect = ServiceOrderFiscalEffect();
const _bEffect = ServiceOrderFiscalEffect(invoiceCancelled: true);

const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';
const _issuerSectionSrc = 'lib/app/modules/establishment/presentation/widget/establishment_issuer_section.dart';
const _apiClientSrc = '../../packages/core/lib/src/shared/http/api_client.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

PagedResult<ServiceOrderListItem> _page(List<int> ids) => PagedResult(
    items: [for (final id in ids) ServiceOrderListItem(id: id, customerId: 1)], page: 1, pageSize: 10, total: ids.length);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState? _shownOrNull(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
ServiceOrderState _shown(List<ServiceOrderState> states) => _shownOrNull(states)!;

/// O one-shot de DESFECHO de um ato (os quatro que a D-F182 identifica) — (é desfecho?, o número que leva).
(bool, int?) _outcome(ServiceOrderState s) => switch (s) {
      ServiceOrderActionSuccess(:final orderNumber) => (true, orderNumber),
      ServiceOrderActionFailure(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalNotice(:final orderNumber) => (true, orderNumber),
      ServiceOrderFiscalWarnings(:final orderNumber) => (true, orderNumber),
      _ => (false, null),
    };

/// O cliente da nfse-api SEM resposta — o que o `_send` do core lança quando o `http` falha (rede, ou a página 502/504 do proxy sem
/// CORS no app WEB — D-F181): `NetworkFailure(detail: e.toString())`.
class _NoResponseNfse extends NfseApiClient {
  _NoResponseNfse() : super(baseUrl: 'https://nfse.setes.example');
  static const _err = NetworkFailure(detail: 'ClientException: XMLHttpRequest error., uri=https://nfse.setes.example/v1/emitter');
  @override
  Future<Map<String, dynamic>> get(String path) async => throw _err;
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? overrideToken}) async => throw _err;
  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async => throw _err;
  @override
  Future<Map<String, dynamic>> delete(String path) async => throw _err;
}

/// O cliente do setes-api SEM resposta — a mesma falha, na OUTRA API (D-F185: a frase neutra é "só nas chamadas à nfse-api").
class _NoResponseApi extends ApiClient {
  _NoResponseApi() : super(baseUrl: 'https://api.setes.example');
  static const _err = NetworkFailure(detail: 'ClientException: XMLHttpRequest error., uri=https://api.setes.example/api/billing/1/cancel-plan');
  @override
  Future<Map<String, dynamic>> get(String path) async => throw _err;
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? overrideToken}) async => throw _err;
  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async => throw _err;
  @override
  Future<Map<String, dynamic>> delete(String path) async => throw _err;
}

/// Uma resposta EM VOO do fuzzer: a chamada fica parada até o agendador decidir (ok / falha).
class _Flight {
  _Flight(this.label, this.instance, this.finish);
  final String label;

  /// A "instância de tela" (contada pelo fuzzer) em que a chamada nasceu.
  final int instance;
  final void Function(bool ok) finish;
  int? get os => int.tryParse(label.split(' ').last);
  String get kind => label.split(' ').first;
}

/// Um diálogo MODAL aberto no Navigator raiz (sobrevive à página recriada — D-F184): a decisão que ele despacha ao confirmar.
class _Dialog {
  _Dialog(this.decision, {this.chain = false});
  final ServiceOrderEvent decision;

  /// Cadeia de dois diálogos (cancelar no fisco: decisão → motivo): página recriada no meio = o 2º não abre (D-F184 — `mounted`).
  final bool chain;
  bool recreatedMeanwhile = false;
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;
  final pt = _load('pt');

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  /// A voz de A: cada leitura pega o PRÓXIMO futuro da fila (ou a voz "do servidor" de agora).
  late List<Completer<Either<Failure, ServiceOrderFiscalView>>> aVoiceQueue;
  late ServiceOrderFiscalView aVoiceNow;
  late int aVoiceReads;

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    aVoiceQueue = [];
    aVoiceNow = _before;
    aVoiceReads = 0;
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => Right(_page([_aId, _bId])));
    when(() => repo.getById(_aId)).thenAnswer((_) async => const Right(_a));
    when(() => repo.getById(_bId)).thenAnswer((_) async => const Right(_b));
    when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) async => const Right(_aEffect));
    when(() => invoice.fiscalEffect(_bId)).thenAnswer((_) async => const Right(_bEffect));
    when(() => nfse.getView(_bId)).thenAnswer((_) async => const Right(_bVoice));
    when(() => nfse.getView(_aId)).thenAnswer((_) {
      aVoiceReads++;
      if (aVoiceQueue.isNotEmpty) return aVoiceQueue.removeAt(0).future;
      return Future.value(Right(aVoiceNow));
    });
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>)> start() async {
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final states = <ServiceOrderState>[];
    final sub = bloc.stream.listen(states.add);
    return (bloc, states, sub);
  }

  /// "Consultar" na A (o 1º ato, em voo), a página RECRIADA (cruzar 1100 px — D-F160), o operador volta a Faturadas e REABRE a A: o
  /// detalhe reaberto chega SEM saving (o ato da tela de antes segue no ar).
  Future<Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>> refreshThenReopenSame(
      ServiceOrderBloc bloc, List<ServiceOrderState> states) async {
    final refresh = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
    when(() => nfse.refresh(_aId)).thenAnswer((_) => refresh.future);
    bloc.add(const ServiceOrderViewRequested(_aId));
    await pumpEventQueue(times: 20);
    bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
    await pumpEventQueue();
    bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
    await pumpEventQueue(times: 20);
    bloc.add(const ServiceOrderListRequested(status: 'F'));
    await pumpEventQueue(times: 20);
    bloc.add(const ServiceOrderViewRequested(_aId));                                   // a MESMA OS reaberta
    await pumpEventQueue(times: 20);
    final reopened = _shown(states) as ServiceOrderDetailState;
    expect([reopened.order.id, reopened.saving], [_aId, false]);
    return refresh;
  }

  // ---------------------------------------------------------------------
  // 1. R12-ADV-01 — a releitura da D-F182 na MESMA OS reaberta × um 2º ato
  //    dela já no ar
  // ---------------------------------------------------------------------
  group('R12-ADV-01 — `_rereadAfterAct` (MESMA OS reaberta) × o 2º ato da OS no ar', () {
    test('[LIMITE CONHECIDO D-F191 (b) na parte (a); CORRIGIDO na parte (b) — a releitura é um PEDIDO NOVO de detalhe, a mais nova vence] era o FATO R12-ADV-01: a OS reaberta chega OCIOSA (sem saving) com o 1º ato dela no ar; o operador começa o 2º ("Transmitir" — saving); o 1º termina e a releitura da D-F182 (2º ramo do `_rereadAfterAct`, pela tela de AGORA) EMITE o detalhe SEM saving com o 2º ato ainda no fisco — os botões reabrem no meio do ato (o 2º clique no Transmitir some em silêncio pela trava por nota; "Cancelar nota"/"Consultar" vão); e as DUAS releituras da mesma tela correm sem ordem: a do 1º ato, que leu a voz ANTES da autorização, chega DEPOIS da do 2º e devolve a tela à voz de antes ("recusada", botão Transmitir) logo depois do "NFS-e autorizada"', () async {
      // (a) o saving do 2º ato cai com o fim do 1º
      final (bloc, states, sub) = await start();
      final refresh = await refreshThenReopenSame(bloc, states);
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmit.future);
      bloc.add(const ServiceOrderTransmitRequested(_aId));                               // o 2º ato, na OS reaberta
      await pumpEventQueue();
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      refresh.complete(const Right(ServiceOrderFiscalRefreshResult()));                  // o 1º termina
      await pumpEventQueue(times: 20);
      final mid = _shown(states) as ServiceOrderDetailState;
      expect([mid.order.id, mid.saving, transmit.isCompleted], [_aId, false, false],
          reason: 'o detalhe da A sem saving com a transmissão dela no ar');
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();

      // (b) as duas releituras fora de ordem
      aVoiceReads = 0;
      final (bloc2, states2, sub2) = await start();
      final refresh2 = await refreshThenReopenSame(bloc2, states2);
      final transmit2 = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmit2.future);
      bloc2.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue();
      final slowRead = Completer<Either<Failure, ServiceOrderFiscalView>>();
      aVoiceQueue.add(slowRead);                                                         // a releitura do 1º: o servidor leu ANTES do commit
      refresh2.complete(const Right(ServiceOrderFiscalRefreshResult()));
      await pumpEventQueue(times: 20);
      aVoiceNow = _after;                                                                // o fisco autorizou
      transmit2.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      expect((_shown(states2) as ServiceOrderDetailState).fiscal, _after, reason: 'a releitura do 2º ato: autorizada');
      slowRead.complete(const Right(_before));                                           // a releitura do 1º chega por último
      await pumpEventQueue(times: 20);
      await sub2.cancel();
      await bloc2.close();
      final authorized = states2.whereType<ServiceOrderActionSuccess>().where((s) => s.messageKey == 'forms.serviceOrder.fiscalAuthorized');
      expect([authorized.single.orderNumber, (_shown(states2) as ServiceOrderDetailState).fiscal], [null, _after],
          reason: '"NFS-e autorizada" (sem prefixo — a tela é a A) e a A na tela com a voz NOVA — a releitura velha perdeu a vez');
    });

    test('[CORRIGIDO R12-ADV-01 LOW — parte (b); a parte (a), o saving, é o LIMITE CONHECIDO da D-F191 (b), fixado no teste acima] com um ato da OS no ar na tela de agora, a releitura de um ato ANTERIOR da mesma OS (D-F182) não tira o saving dele nem sobrescreve uma releitura mais nova — "vale o último pedido" também entre as releituras da mesma tela. Correção sugerida: o 2º ramo do `_rereadAfterAct` re-emite com o saving do ato da tela de agora (ou deixa a releitura para o fim dele), e a releitura leva um número próprio (a mais nova vence)', () async {
      // (b) a releitura mais NOVA vence
      final (bloc2, states2, sub2) = await start();
      final refresh2 = await refreshThenReopenSame(bloc2, states2);
      final transmit2 = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmit2.future);
      bloc2.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue();
      final slowRead = Completer<Either<Failure, ServiceOrderFiscalView>>();
      aVoiceQueue.add(slowRead);
      refresh2.complete(const Right(ServiceOrderFiscalRefreshResult()));
      await pumpEventQueue(times: 20);
      aVoiceNow = _after;
      transmit2.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      slowRead.complete(const Right(_before));
      await pumpEventQueue(times: 20);
      await sub2.cancel();
      await bloc2.close();
      expect((_shown(states2) as ServiceOrderDetailState).fiscal, _after, reason: 'a tela fica com a releitura mais NOVA');
    });
  });

  // ---------------------------------------------------------------------
  // 2. R12-ADV-02 — o fim do ato com a MESMA OS "a caminho"
  // ---------------------------------------------------------------------
  group('R12-ADV-02 — o desfecho × a MESMA OS reaberta ainda A CAMINHO', () {
    Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>, Completer<Either<Failure, ServiceOrderFiscalView>>)>
        transmitThenReopenOnTheWay(Completer<Either<Failure, ServiceOrderTransmitResult>> transmit) async {
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmit.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));                               // o fisco demora (até 210 s)
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      final onTheWay = Completer<Either<Failure, ServiceOrderFiscalView>>();
      aVoiceQueue.add(onTheWay);                                                         // a voz do detalhe reaberto: lida ANTES do commit
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // reabre a A — a caminho
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue);
      return (bloc, states, sub, onTheWay);
    }

    test('[CORRIGIDO D-F191 (a) — era o FATO R12-ADV-02: a OS a caminho conta como a tela dela (sem prefixo) e é PEDIDA DE NOVO] o ato termina no intervalo em que a MESMA OS reaberta ainda está A CAMINHO (o GET da OS voltou, a voz do fisco não): o `_detail` ainda é nulo — `_outcomeOrder` diz "outra tela" (o desfecho sai com "OS 7374: " sobre a própria 7374 que está abrindo) e o `_rereadAfterAct` não relê; a voz do detalhe a caminho, lida ANTES da autorização, chega depois e a OS 7374 fica "recusada" (botão Transmitir) com o "OS 7374: NFS-e autorizada" na tela — o R11-ADV-02 pela janela do "a caminho" (R10-SOC-01: "aberto" e "a caminho" são UM estado)', () async {
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      final (bloc, states, sub, onTheWay) = await transmitThenReopenOnTheWay(transmit);
      final reads = aVoiceReads;
      aVoiceNow = _after;
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      onTheWay.complete(const Right(_before));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final authorized = states.whereType<ServiceOrderActionSuccess>().single;
      final shown = _shown(states) as ServiceOrderDetailState;
      expect([authorized.messageKey, authorized.orderNumber, shown.order.id, shown.fiscal, aVoiceReads - reads > 0],
          ['forms.serviceOrder.fiscalAuthorized', null, _aId, _after, true]);
    });

    test('[CORRIGIDO R12-ADV-02 LOW — D-F191 (a)] o fim de um ato com a MESMA OS reaberta A CAMINHO relê (ou o detalhe a caminho é pedido de novo): a OS na tela nunca fica com a voz de antes do ato que ela mesma acabou de anunciar. Correção sugerida: o bloc guardar o ID do detalhe a caminho junto do `_pendingDetailScreen` e o `_rereadAfterAct`/`_outcomeOrder` tratarem "a caminho da MESMA OS" como a OS aberta (R10-SOC-01)', () async {
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      final (bloc, states, sub, onTheWay) = await transmitThenReopenOnTheWay(transmit);
      aVoiceNow = _after;
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      onTheWay.complete(const Right(_before));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect((_shown(states) as ServiceOrderDetailState).fiscal, _after);
    });
  });

  // ---------------------------------------------------------------------
  // 3. Q-F195-ADV-01 — XML/DANFSe: o documento de uma OS abre sobre outra
  // ---------------------------------------------------------------------
  group('Q-F195-ADV-01 — XML/DANFSe fora da tela da OS', () {
    test('[DECIDIDO D-F189 (+ Q-F195-ADV-01 (a)) — era o FATO: o documento de OUTRA OS leva o NÚMERO dela; a página abre e diz "OS N: documento aberto em nova aba"] a D-F182 identifica os quatro one-shots de desfecho, mas não os do DOCUMENTO: "DANFSe" na OS A (o PDF demora), a página recriada, o operador abre a OS B — o `ServiceOrderFiscalDanfseReady` da A chega com a B na tela, SEM identidade (props = só o base64), e a página o abre numa aba nova sem dizer de que OS é (o operador olhando a B recebe o DANFSe da A). O mesmo com o XML', () async {
      final danfse = Completer<Either<Failure, String>>();
      final xml = Completer<Either<Failure, String>>();
      when(() => nfse.danfse(_aId)).thenAnswer((_) => danfse.future);
      when(() => nfse.xml(_aId)).thenAnswer((_) => xml.future);
      final (bloc, states, sub) = await start();
      for (final ask in const <ServiceOrderEvent>[ServiceOrderFiscalDanfseRequested(_aId), ServiceOrderFiscalXmlRequested(_aId)]) {
        bloc.add(const ServiceOrderViewRequested(_aId));
        await pumpEventQueue(times: 20);
        bloc.add(ask);
        await pumpEventQueue();
        bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));              // a página recriada
        await pumpEventQueue(times: 20);
        bloc.add(const ServiceOrderViewRequested(_bId));
        await pumpEventQueue(times: 20);
      }
      final at = states.length;
      danfse.complete(const Right('JVBERi0xLjQ='));
      xml.complete(const Right('<NFSe/>'));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final after = states.sublist(at);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _bId);
      expect(after.whereType<ServiceOrderFiscalDanfseReady>().single.props, ['JVBERi0xLjQ=', _aId]);
      expect(after.whereType<ServiceOrderFiscalXmlReady>().single.props, ['<NFSe/>', _aId]);
      final page = File(_pageSrc).readAsStringSync();
      expect([page.contains('_openDanfse(state.pdfBase64, _about(state.orderNumber));'), page.contains('_openXml(state.xml, _about(state.orderNumber));'),
          page.contains("'forms.serviceOrder.fiscalDocOpened'")], [true, true, true]);
    });
  });

  // ---------------------------------------------------------------------
  // 4. R12-ADV-03 — D-F185 × a OUTRA porta da nfse-api no app (Emissor fiscal)
  // ---------------------------------------------------------------------
  group('R12-ADV-03 — D-F185 × o Emissor fiscal (nfse-api `/v1/emitter*`)', () {
    Future<(Failure, Failure)> bothFailures() async {
      final client = _NoResponseNfse();
      Failure? issuer;
      try {
        await EstablishmentIssuerDatasourceImpl(client: client).get();
      } on Failure catch (f) {
        issuer = f;
      }
      final os = (await ServiceOrderNfseRepositoryImpl(datasource: ServiceOrderNfseDatasourceImpl(client: client)).getView(_aId))
          .fold((f) => f, (_) => null);
      return (issuer!, os!);
    }

    test('[CORRIGIDO D-F204 — era o FATO R12-ADV-03; a frase da rede é NEUTRA no app inteiro] a frase neutra da D-F185 vive só no repositório da OS (`ServiceOrderNfseRepositoryImpl._guard`); a OUTRA porta do app para a nfse-api — o Emissor fiscal do estabelecimento (`EstablishmentIssuerDatasourceImpl`: GET/PUT/DELETE `/v1/emitter*`, o mesmo `NfseApiClient`, o mesmo proxy na frente) — devolve a MESMA falta de resposta com `core.errors.network` ("Falha de conexão com o servidor"), e a seção a entrega crua à ponte (`showFailureFeedback(context, failure)`): a frase de conexão que a D-F181/D-F185 tirou dos atos fiscais', () async {
      final (issuer, os) = await bothFailures();
      expect([issuer is NetworkFailure, os is NetworkFailure, issuer.supportRef == os.supportRef], [true, true, true]);
      expect([issuer.message.tr(), os.message.tr()], ['Sem resposta do serviço — rede, proxy ou tempo.', 'Sem resposta do serviço — rede, proxy ou tempo.']);
      final section = File(_issuerSectionSrc).readAsStringSync();
      expect(RegExp(r'showFailureFeedback\(context, failure\)').allMatches(section).length, 2);
    });

    test('[RESISTIU] D-F185 com os repositórios REAIS sobre os clientes sem resposta: TODA chamada da OS à nfse-api (voz, transmitir, consultar, reconferir, cancelar no fisco, XML, DANFSe, pendentes) devolve `NetworkFailure` com a frase neutra — tipo, ref e "desfecho desconhecido" preservados; o lote fiscal (usecase real) faz a linha "rede" sem o texto da exceção; e SÓ nelas: o setes-api (plano, efeito, cancelar a nota, manter a nota) segue com `core.errors.network` — na saga, o passo do plano e o da nota dizem a frase de conexão, o do fisco a neutra', () async {
      final nfseRepo = ServiceOrderNfseRepositoryImpl(datasource: ServiceOrderNfseDatasourceImpl(client: _NoResponseNfse()));
      final invoiceRepo = ServiceOrderInvoiceRepositoryImpl(datasource: ServiceOrderInvoiceDatasourceImpl(client: _NoResponseApi()));
      Failure left<T>(Either<Failure, T> e) => e.fold((f) => f, (_) => throw StateError('devia falhar'));
      final nfseCalls = <Failure>[
        left(await nfseRepo.getView(1)), left(await nfseRepo.transmit(1)), left(await nfseRepo.refresh(1)),
        left(await nfseRepo.reconfirm(1)), left(await nfseRepo.cancel(1, 'm')), left(await nfseRepo.xml(1)),
        left(await nfseRepo.danfse(1)), left(await nfseRepo.pending()),
      ];
      for (final f in nfseCalls) {
        expect([f is NetworkFailure, f.message, isUnknownAuthorityOutcome(f), f.supportRef?.startsWith('ClientException')],
            [true, 'forms.serviceOrder.fiscalNoResponse', true, true]);
      }
      final erpCalls = <Failure>[
        left(await invoiceRepo.cancelPlan(1)), left(await invoiceRepo.fiscalEffect(1)), left(await invoiceRepo.cancel(1, 'm')),
        left(await invoiceRepo.cancelWaiver(1, 'm')),
      ];
      for (final f in erpCalls) {
        expect([f is NetworkFailure, f.message], [true, 'core.errors.network']);
      }
      final batch = await ServiceOrderFiscalTransmitBatch(repository: nfseRepo, maxConsecutiveUnknown: 99).call([1, 2]);
      expect([for (final r in batch.uncertainRows) [r.network, r.supportRef, r.uncertainDetail]], [[true, '', ''], [true, '', '']]);
      final saga = ServiceOrderCancelInvoice(nfse: nfseRepo, invoice: invoiceRepo);
      final local = (await saga(1, 'm', atAuthority: false)).fold((f) => f, (_) => null)!;
      final plan = (await saga(1, 'm', atAuthority: true)).fold((f) => f, (_) => null)!;
      expect([local.stage, local.failure.message, plan.stage, plan.failure.message],
          [CancelSagaStage.invoice, 'core.errors.network', CancelSagaStage.plan, 'core.errors.network']);
    });

    test('[CORRIGIDO D-F204 — era o ACHADO R12-ADV-03 LOW] D-F185 ("a frase NEUTRA … só nas chamadas à nfse-api") em TODA chamada do app à nfse-api: o Emissor fiscal (salvar a habilitação, enviar/remover o A1, ler a visão) sem resposta diz a frase neutra, como os atos fiscais da OS. Correção sugerida: a troca da mensagem numa peça da borda da nfse-api (ou no `NfseApiClient`), não no repositório de UM módulo', () async {
      final (issuer, os) = await bothFailures();
      expect(issuer.message.tr(), os.message.tr());
    });
  });

  // ---------------------------------------------------------------------
  // 5. R12-ADV-04 — a cerca de `ClientFailureCodes.all`
  // ---------------------------------------------------------------------
  group('R12-ADV-04 — a cerca de `ClientFailureCodes.all` (R11-SOC-04)', () {
    /// A extração da cerca do repositório (`service_order_fiscal_entity_test.dart`, "R11-SOC-04 (cerca)"), LITERAL.
    Set<String?> repoFence(String src) {
      final body = src.substring(src.indexOf('abstract final class ClientFailureCodes'), src.indexOf('static const all'));
      return RegExp(r"static const \w+ = '([A-Z_]+)';").allMatches(body).map((m) => m.group(1)).toSet();
    }

    /// A cerca ROBUSTA: o corpo inteiro da classe (pelas chaves), qualquer `static const [String] x = '…'|"…"` exceto o `all`.
    Set<String> robustFence(String src) {
      final start = src.indexOf('abstract final class ClientFailureCodes');
      final open = src.indexOf('{', start);
      var depth = 0;
      var end = open;
      for (var i = open; i < src.length; i++) {
        if (src[i] == '{') depth++;
        if (src[i] == '}' && --depth == 0) {
          end = i;
          break;
        }
      }
      final body = src.substring(open, end);
      return RegExp(r'''static\s+const\s+(?:String\s+)?(\w+)\s*=\s*['"]([^'"]+)['"]\s*;''')
          .allMatches(body)
          .where((m) => m.group(1) != 'all')
          .map((m) => m.group(2)!)
          .toSet();
    }

    final src = File(_apiClientSrc).readAsStringSync();
    const allLine = 'static const all = {invalidResponse, configuration, sessionNotAccepted, clock};';   // D-F219: + clock
    final variants = {
      'declarado DEPOIS do all': src.replaceFirst(allLine, "$allLine\n\n  static const timeout = 'CLIENT_TIMEOUT';"),
      'com o tipo explícito': src.replaceFirst('  static const all', "  static const String timeout = 'CLIENT_TIMEOUT';\n\n  static const all"),
      'com dígito no código': src.replaceFirst('  static const all', "  static const http2 = 'CLIENT_HTTP2';\n\n  static const all"),
    };

    test('[FATO R12-ADV-04] a cerca da R11-SOC-04 ("todo código declarado na classe entra na lista") é CEGA para três formas comuns de declarar o código novo: DEPOIS da linha do `all` (o corte do texto é o `static const all`), com o tipo explícito (`static const String x = …`) e com dígito no valor (`[A-Z_]+`) — nos três o código novo NÃO está no `all` e a cerca passa (a linha do lote mostraria o texto do Dart como "ref" — D-F180)', () {
      expect(src.contains(allLine), isTrue, reason: 'a linha do all mudou — atualize o teste');
      for (final e in variants.entries) {
        expect([e.key, e.value != src], [e.key, true]);
        expect([e.key, repoFence(e.value)], [e.key, ClientFailureCodes.all], reason: 'a cerca do repositório não vê o código novo');
      }
    });

    test('[CERCA R12-ADV-04] a cerca robusta (o corpo inteiro da classe pelas chaves; tipo opcional; qualquer valor) enxerga as três formas e, sobre o fonte de HOJE, bate com `ClientFailureCodes.all`', () {
      expect(robustFence(src), ClientFailureCodes.all);
      for (final e in variants.entries) {
        expect([e.key, robustFence(e.value).difference(ClientFailureCodes.all).isNotEmpty], [e.key, true]);
      }
    });
  });

  // ---------------------------------------------------------------------
  // 5b. R12-ADV-06 — o "número da OS" do desfecho é o ID interno
  // ---------------------------------------------------------------------
  group('R12-ADV-06 — o número da OS no desfecho (D-F182) × o número que a tela mostra', () {
    /// A forma REAL do dado da Setes (dev, 2026-10-13, SELECT só leitura em `setes_setes.tb_service_order`): 344 de 344 OS com
    /// `number` ≠ `id` — a OS que a tela mostra como "7374" tem id 8011 (ids 7492–8011 × números 6998–7374).
    const xId = 8011;
    const xNumber = 7374;
    const x = ServiceOrderFull(id: xId, number: xNumber, customerId: 1, status: 'F');

    Future<ServiceOrderActionSuccess> authorizedWithScreenGone() async {
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => repo.getById(xId)).thenAnswer((_) async => const Right(x));
      when(() => invoice.fiscalEffect(xId)).thenAnswer((_) async => const Right(_aEffect));
      when(() => nfse.getView(xId)).thenAnswer((_) async => const Right(_before));
      when(() => nfse.transmit(xId)).thenAnswer((_) => transmit.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(xId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(xId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada — a tela é a lista
      await pumpEventQueue(times: 20);
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: xId, attempt: 1, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      return states.whereType<ServiceOrderActionSuccess>().single;
    }

    test('[CORRIGIDO D-F187 — era o FATO R12-ADV-06: o desfecho leva o NÚMERO que a tela mostra] a D-F182 decidiu "o desfecho leva o NÚMERO da OS (\'OS 7374: NFS-e autorizada — …\')", mas o bloc põe no one-shot o `orderId` (o ID interno — a identidade da nota na nfse-api) e a página prefixa ESSE valor ("OS 8011: "), enquanto a lista (avatar) e o cabeçalho do detalhe mostram `order.number ?? order.id` ("7374"): o operador procura a OS 8011 e não a acha; quando os números da OS chegarem a 7492 (o menor id de hoje — ~118 OS adiante; num cliente com vendas e OS no mesmo `tb_order`, já), "OS 7492: …" passa a ser lido como o desfecho de OUTRA OS — o que a D-F182 existe para impedir. (As linhas dos relatórios de lote — "Ordem {}" — já usavam o id: anterior ao delta, mesma classe)', () async {
      final success = await authorizedWithScreenGone();
      expect(success.orderNumber, xNumber);
      expect('forms.serviceOrder.outcomeOfOrder'.tr(args: ['${success.orderNumber}']), 'OS 7374: ');
      final page = File(_pageSrc).readAsStringSync();
      expect(page, contains(r"orderId == null ? '' : 'forms.serviceOrder.outcomeOfOrder'.tr(args: ['$orderId']);"));   // o prefixo recebe o NÚMERO
      expect(page, contains(r"CircleAvatar(child: SetesText('${order.number ?? order.id}'))"));
      expect(page, contains(r".tr(args: ['${order.number ?? order.id}'])"));
    });

    test('[CORRIGIDO R12-ADV-06 MEDIUM — D-F187] o desfecho fora da tela da OS identifica a OS pelo número que o operador VÊ (`number ?? id`): "OS 7374: NFS-e autorizada" — nunca o id interno. Correção sugerida: o ato captura o número da OS ao começar (o detalhe dele) e o one-shot leva esse número (o id segue sendo a identidade da nota na nfse-api)', () async {
      final success = await authorizedWithScreenGone();
      expect(success.props, contains(xNumber));
    });
  });

  // ---------------------------------------------------------------------
  // 6. D-F182/D-F183/D-F184 — o que RESISTIU (sequências dirigidas)
  // ---------------------------------------------------------------------
  group('D-F182/D-F183/D-F184 — sequências dirigidas', () {
    test('[RESISTIU] D-F184: as decisões que um diálogo despacha DEPOIS da página recriada (a tela é a lista) — cancelar a nota (saga sem o fisco e com o fisco), "manter a nota", reconferir — vão ao bloc e o desfecho leva o NÚMERO da OS; nenhum detalhe é emitido por cima da lista e nenhum `saving` aparece', () async {
      when(() => invoice.cancel(_aId, any())).thenAnswer((_) async => const Right(ServiceOrderInvoiceCancelResult(orderId: _aId, invoiceNumber: '55')));
      when(() => invoice.cancelPlan(_aId)).thenAnswer((_) async => const Right(ServiceOrderCancelPlan(orderId: _aId, blocks: [
            CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
          ])));
      when(() => nfse.cancel(_aId, any())).thenAnswer((_) async => const Right(ServiceOrderFiscalCancelResult(invoiceId: _aId, warnings: ['aviso'])));
      when(() => invoice.cancelWaiver(_aId, any())).thenAnswer((_) async => const Right(ServiceOrderCancelWaiverResult(orderId: _aId)));
      when(() => nfse.reconfirm(_aId)).thenAnswer((_) async => const Right(ServiceOrderFiscalReconfirmResult(needed: true, verdict: 'provada')));
      final (bloc, states, sub) = await start();
      final outcomes = <ServiceOrderState>[];
      var details = 0;
      for (final decision in const <ServiceOrderEvent>[
        ServiceOrderCancelConfirmed(orderId: _aId, reason: 'motivo', atAuthority: false),
        ServiceOrderCancelConfirmed(orderId: _aId, reason: 'motivo', atAuthority: true),
        ServiceOrderFiscalCancelWaiverRequested(orderId: _aId, reason: 'manter'),
        ServiceOrderFiscalReconfirmRequested(_aId),
      ]) {
        // cada diálogo é de uma visita à OS: a página recriada antes da confirmação deixa a tela na LISTA
        bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
        await pumpEventQueue(times: 20);
        final at = states.length;
        bloc.add(decision);
        await pumpEventQueue(times: 20);
        outcomes.addAll(states.sublist(at).where((s) => _outcome(s).$1));
        details += states.sublist(at).whereType<ServiceOrderDetailState>().length;
      }
      await sub.cancel();
      await bloc.close();
      expect(outcomes.length, 5, reason: 'cancelada ×2 (+ o aviso do fisco), mantida, reconferida');
      expect(outcomes.map((s) => _outcome(s).$2).toSet(), {_aId});
      expect(details, 0);
    });

    test('[RESISTIU] D-F182/D-F183: dois atos em voo em OS DIFERENTES (Transmitir na A; a saga do cancelamento na B) com as respostas fora de ordem: o fim da A (com a B na tela) leva "OS 7374", não relê e não mexe no saving da B; o fim da B (na tela dela) vai sem prefixo e relê a B; no repouso nada fica em saving', () async {
      final transmitA = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      final localB = Completer<Either<Failure, ServiceOrderInvoiceCancelResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmitA.future);
      when(() => invoice.cancel(_bId, any())).thenAnswer((_) => localB.future);
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _bId, reason: 'motivo', atAuthority: false));
      await pumpEventQueue();
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      var at = states.length;
      transmitA.complete(const Left(Failure(message: 'x', statusCode: 422, code: 'FISCAL_DPS_REJECTED')));
      await pumpEventQueue(times: 20);
      expect(states.sublist(at).whereType<ServiceOrderDetailState>(), isEmpty, reason: 'o fim da A não toca a tela da B');
      expect(states.sublist(at).where((s) => _outcome(s).$1).map((s) => _outcome(s).$2).toList(), [_aId]);
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      at = states.length;
      final bReads = states.whereType<ServiceOrderDetailState>().length;
      localB.complete(const Right(ServiceOrderInvoiceCancelResult(orderId: _bId, invoiceNumber: '9')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.sublist(at).where((s) => _outcome(s).$1).map((s) => _outcome(s).$2).toList(), [null]);
      final shown = _shown(states) as ServiceOrderDetailState;
      expect([shown.order.id, shown.saving, states.whereType<ServiceOrderDetailState>().length > bReads], [_bId, false, true]);
    });
  });

  // ---------------------------------------------------------------------
  // 7. FUZZ — o desfecho identificado (D-F182) com os diálogos MODAIS que
  //    sobrevivem à página recriada (D-F184) e as travas por nota (D-F183)
  // ---------------------------------------------------------------------
  group('fuzz do bloc — 300 sementes (desfecho identificado)', () {
    test('[RESISTIU] em 300 sequências aleatórias (ver/abrir/voltar/aba, página recriada a qualquer momento — também com um diálogo MODAL aberto, que despacha a decisão DEPOIS (D-F184): manter a nota, cancelar (o plano abre o diálogo; com a barreira "autorizada" a cadeia de dois diálogos, que cai se a página foi recriada no meio), item, faturar, cancelar OS, abrir OS, rotina mensal, lote de faturamento, pendentes → lote fiscal; atos diretos — transmitir, consultar, XML, DANFSe; cada resposta em ordem aleatória, ~25 % falhas): TODO desfecho de um ato sai SEM número quando a tela de agora é a OS dele e COM o número dela quando não é (D-F182); o plano só abre o diálogo sobre a OS que o pediu; no repouso nada fica em spinner/saving e o detalhe tem a voz da SUA OS', () async {
      const voiceOf = {_aId: _before, _bId: _bVoice};
      const effectOf = {_aId: _aEffect, _bId: _bEffect};
      const orderOf = {_newId: _newOrder, _aId: _a, _bId: _b};
      final cover = <String, int>{};
      void count(String k) => cover[k] = (cover[k] ?? 0) + 1;
      var savingDropped = 0;   // R12-ADV-01 no fuzz: detalhe X sem saving com um ato de X nascido NESTA tela ainda no ar
      for (var seed = 1; seed <= 300; seed++) {
        final rnd = Random(seed);
        final flights = <_Flight>[];
        final trace = <String>[];
        // "instância de tela": muda a cada lista emitida ou a cada detalhe de OUTRA OS (contada pelo listener)
        var instance = 0;
        int? shownDetailId;
        Failure fail() => rnd.nextBool() ? const Failure(message: 'x', statusCode: 500) : const NetworkFailure();
        Future<Either<Failure, T>> park<T>(String label, T Function() ok) {
          final c = Completer<Either<Failure, T>>();
          flights.add(_Flight(label, instance, (good) => c.complete(good ? Right(ok()) : Left(fail()))));
          return c.future;
        }

        repo = ServiceOrderRepoMock();
        nfse = NfseRepoMock();
        invoice = InvoiceRepoMock();
        when(() => repo.getList(any(), any(),
                page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
            .thenAnswer((_) => park('list', () => _page([_newId, _aId, _bId])));
        for (final id in orderOf.keys) {
          when(() => repo.getById(id)).thenAnswer((_) => park('get $id', () => orderOf[id]!));
        }
        const authorizedPlanBlocks = [
          CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
        ];
        for (final id in voiceOf.keys) {
          when(() => nfse.getView(id)).thenAnswer((_) => park('voice $id', () => voiceOf[id]!));
          when(() => invoice.fiscalEffect(id)).thenAnswer((_) => park('effect $id', () => effectOf[id]!));
          when(() => nfse.refresh(id)).thenAnswer((_) => park('refresh $id', () => const ServiceOrderFiscalRefreshResult()));
          when(() => nfse.xml(id)).thenAnswer((_) => park('xml $id', () => '<x/>'));
          when(() => nfse.danfse(id)).thenAnswer((_) => park('danfse $id', () => 'JVBE'));
          when(() => invoice.cancelPlan(id)).thenAnswer((_) => park('plan $id',
              () => rnd.nextBool() ? ServiceOrderCancelPlan(orderId: id, cancellable: true) : ServiceOrderCancelPlan(orderId: id, blocks: authorizedPlanBlocks)));
          when(() => nfse.cancel(id, any())).thenAnswer((_) => park('nfsecancel $id', () => ServiceOrderFiscalCancelResult(invoiceId: id, warnings: const ['aviso'])));
          when(() => invoice.cancel(id, any())).thenAnswer((_) => park('localcancel $id', () => ServiceOrderInvoiceCancelResult(orderId: id, invoiceNumber: '9')));
          when(() => invoice.cancelWaiver(id, any())).thenAnswer((_) => park('waiver $id', () => ServiceOrderCancelWaiverResult(orderId: id)));
        }
        when(() => nfse.transmit(any())).thenAnswer((inv) {
          final id = inv.positionalArguments[0] as int;
          return park('transmit $id', () => ServiceOrderTransmitResult(invoiceId: id, attempt: 1, accessKey: 'K'));
        });
        when(() => repo.open(5)).thenAnswer((_) => park('post', () => _newId));
        when(() => repo.itemPost(_newId, any())).thenAnswer((_) => park('item $_newId', () => 1));
        when(() => repo.invoice(_newId, any())).thenAnswer((_) => park('invoice $_newId', () => const ServiceOrderInvoiceResult(invoiceNumber: '1')));
        when(() => repo.cancel(_newId)).thenAnswer((_) => park('cancelOs $_newId', () => unit));
        when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
        when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => park('batch', () => BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: _newId, ok: true)])));
        when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
            .thenAnswer((_) => park('pending', () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId)], page: 1, pageSize: 100, total: 1)));

        const actKinds = {'transmit', 'refresh', 'xml', 'danfse', 'plan', 'nfsecancel', 'localcancel', 'waiver', 'item', 'invoice', 'cancelOs'};
        final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
        final states = <ServiceOrderState>[];
        String why() => 'seed $seed\n${trace.join('\n')}';
        final sub = bloc.stream.listen((s) {
          if (s is ServiceOrderListState) {
            instance++;
            shownDetailId = null;
          } else if (s is ServiceOrderDetailState) {
            if (shownDetailId != s.order.id) instance++;
            shownDetailId = s.order.id;
            if (!s.saving && flights.any((f) => actKinds.contains(f.kind) && f.os == s.order.id && f.instance == instance)) {
              savingDropped++;
              trace.add('!! detalhe ${s.order.id} sem saving com ato dele no ar nesta tela');
            }
          }
          states.add(s);
        });
        _Dialog? dialog;
        var pendingSeen = 0;
        var planSeen = 0;
        void add(ServiceOrderEvent e) {
          trace.add('${e.runtimeType}${e.props}');
          if (!bloc.isClosed) bloc.add(e);                                              // o `_dispatch` da página (D-F184)
        }

        Future<void> completeOne({double okRate = 0.75}) async {
          // o fisco é LENTO: um ato no ar tem 1/3 do peso das leituras na hora de responder (o operador navega com ele no ar)
          var i = rnd.nextInt(flights.length);
          for (var retry = 0; retry < 2 && actKinds.contains(flights[i].kind) && flights.length > 1; retry++) {
            i = rnd.nextInt(flights.length);
          }
          final f = flights.removeAt(i);
          final ok = rnd.nextDouble() < okRate;
          final shownBefore = _shownOrNull(states);
          final at = states.length;
          trace.add('<- ${f.label} ${ok ? 'ok' : 'FAIL'}');
          f.finish(ok);
          await pumpEventQueue();
          if (!actKinds.contains(f.kind)) return;
          // D-F182: o desfecho deste ato — sem número sobre a OS dele; com o número dela sobre qualquer outra tela
          final onOwn = shownBefore is ServiceOrderDetailState && shownBefore.order.id == f.os;
          // D-F191 (= Q-F195-SOC-05 (a), Valdo 2026-10-13): a OS do ato A CAMINHO (a lista em loading com uma carga dela no ar) conta como a
          // tela DELA — o desfecho pode sair sem número (a OS é pedida de novo); fora disso, a regra estrita da D-F182
          final onTheWay = shownBefore is! ServiceOrderDetailState &&
              flights.any((x) => x.label == 'get ${f.os}' || x.label == 'voice ${f.os}' || x.label == 'effect ${f.os}');
          for (final s in states.sublist(at)) {
            final (isOutcome, about) = _outcome(s);
            if (isOutcome) {
              count(about == null ? 'outcomeOnOwn' : 'outcomeElsewhere');
              final reason = 'desfecho de ${f.label} com o número errado (tela: ${shownBefore.runtimeType}${shownBefore is ServiceOrderDetailState ? ' ${shownBefore.order.id}' : ''}) — ${why()}';
              if (onTheWay) {
                expect(about == null || about == f.os, isTrue, reason: reason);
              } else {
                expect(about, onOwn ? isNull : f.os, reason: reason);
              }
            }
            if (s is ServiceOrderCancelPlanReady) {
              // D-F194 (= Q-F196-SOC-03 (a)): também com a MESMA OS a caminho
              expect([onOwn || onTheWay, s.plan.orderId], [true, f.os], reason: 'o plano abriu o diálogo fora da OS que o pediu — ${why()}');
            }
          }
        }

        add(const ServiceOrderListRequested(status: 'A', filter: ''));                 // o initState
        await pumpEventQueue();
        for (var step = 0; step < 120; step++) {
          if (flights.isNotEmpty && rnd.nextDouble() < 0.5) {
            await completeOne();
            continue;
          }
          final pick = rnd.nextInt(100);
          final shown = _shownOrNull(states);
          // um diálogo MODAL aberto: só a página recriada (resize) e o confirmar/cancelar
          final d = dialog;
          if (d != null) {
            if (pick < 15) {
              d.recreatedMeanwhile = true;
              count('recreatedUnderDialog');
              add(const ServiceOrderListRequested(status: 'A', filter: ''));
            } else if (pick < 85) {
              dialog = null;
              // D-F189 (= Q-F195-SOC-03 (a)): o 2º diálogo da cadeia abre pelo Navigator RAIZ — a decisão vai mesmo com a página recriada
              if (d.chain && d.recreatedMeanwhile) count('chainAfterRecreate');
              if (d.recreatedMeanwhile) count('decisionAfterRecreate');
              add(d.decision);
            } else if (pick < 95) {
              dialog = null;                                                              // cancelou
            }
            await pumpEventQueue();
            continue;
          }
          // one-shots que abrem diálogo por cima de QUALQUER tela (o listener da página)
          final plans = states.whereType<ServiceOrderCancelPlanReady>().toList();
          if (plans.length > planSeen) {
            planSeen = plans.length;
            final plan = plans.last.plan;
            dialog = plan.onlyAuthorityStands
                ? _Dialog(ServiceOrderCancelConfirmed(orderId: plan.orderId, reason: 'motivo', atAuthority: true), chain: true)
                : _Dialog(ServiceOrderCancelConfirmed(orderId: plan.orderId, reason: 'motivo', atAuthority: false));
            continue;
          }
          final loaded = states.whereType<ServiceOrderFiscalPendingLoaded>().length;
          if (loaded > pendingSeen) {
            pendingSeen = loaded;
            dialog = _Dialog(const ServiceOrderFiscalTransmitBatchRequested([_aId]));
            continue;
          }
          final recreate = shown is ServiceOrderDetailState && shown.saving ? pick < 35 : pick < 6;
          if (recreate) {
            if (shown is ServiceOrderDetailState && shown.saving) count('recreatedWhileSaving');
            add(const ServiceOrderListRequested(status: 'A', filter: ''));
          } else if (shown is ServiceOrderDetailState) {
            if (shown.saving) {
              // botões travados — esperar
            } else if (pick < 15) {
              add(const ServiceOrderBackToListPressed());
            } else if (shown.order.isOpen) {
              final r = rnd.nextInt(3);
              dialog = _Dialog(r == 0
                  ? const ServiceOrderItemSaveRequested(orderId: _newId, input: _item)
                  : r == 1
                      ? const ServiceOrderInvoiceRequested(orderId: _newId, input: _input)
                      : const ServiceOrderCancelRequested(_newId));
            } else {
              final id = shown.order.id;
              // a OS reaberta com um ato DELA de outra tela ainda no ar (o caso da D-F182/D-F183): o 2º ato é mais provável
              final olderAct = flights.any((f) => actKinds.contains(f.kind) && f.os == id && f.instance != instance);
              if (olderAct) count('reopenedWithActInFlight');
              final r = olderAct && rnd.nextBool() ? 1 + rnd.nextInt(3) : rnd.nextInt(7);
              if (r == 0) {
                dialog = _Dialog(ServiceOrderFiscalCancelWaiverRequested(orderId: id, reason: 'manter'));
              } else {
                final before = flights.length;
                add([
                  ServiceOrderTransmitRequested(id),
                  ServiceOrderTransmitRequested(id),
                  ServiceOrderFiscalRefreshRequested(id),
                  ServiceOrderFiscalXmlRequested(id),
                  ServiceOrderFiscalDanfseRequested(id),
                  ServiceOrderCancelFlowRequested(id),
                ][r - 1]);
                await pumpEventQueue();
                if (r <= 2 && flights.length == before) count('sameNoteClickIgnored');   // D-F183: a trava por nota
                continue;
              }
            }
          } else if (shown is ServiceOrderListState) {
            if (shown.loading) {
              // o detalhe pedido está a caminho: o operador espera (quase sempre)
              final waitingDetail = states.isNotEmpty && states.last is ServiceOrderListState && (states.last as ServiceOrderListState).loading &&
                  trace.lastWhere((t) => !t.startsWith('<-'), orElse: () => '').startsWith('ServiceOrderViewRequested');
              if (waitingDetail && pick < 90) {
                // esperar
              } else if (pick < 35) {
                add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
              } else if (pick < 45) {
                dialog = _Dialog(const ServiceOrderOpenRequested(5));                     // o FAB (lookup de cliente)
              }
            } else if (pick < 60) {
              // reabrir a OS de um ato ainda no ar (página recriada no meio dele) — metade das vezes, quando existe
              final inAir = flights.where((f) => actKinds.contains(f.kind) && (f.os == _aId || f.os == _bId)).map((f) => f.os!).toList();
              if (inAir.isNotEmpty) count('viewInAir');
              add(ServiceOrderViewRequested(inAir.isNotEmpty && rnd.nextBool()
                  ? inAir[rnd.nextInt(inAir.length)]
                  : [_aId, _bId, _aId, _bId, _newId][rnd.nextInt(5)]));
            } else if (pick < 64) {
              dialog = _Dialog(const ServiceOrderOpenRequested(5));
            } else if (pick < 72) {
              add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
            } else if (pick < 77) {
              dialog = _Dialog(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
            } else if (pick < 85) {
              add(const ServiceOrderFiscalPendingRequested());
            } else if (pick < 90) {
              dialog = _Dialog(const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input));
            }
          }
          await pumpEventQueue();
        }

        // repouso: fecha o diálogo (se houver) e drena
        dialog = null;
        for (var guard = 0; flights.isNotEmpty; guard++) {
          expect(guard, lessThan(3000), reason: 'seed $seed não drena');
          await completeOne(okRate: 0.85);
        }
        await pumpEventQueue(times: 20);
        final rest = _shown(states);
        if (rest is ServiceOrderListState) {
          expect(rest.loading, isFalse, reason: 'spinner preso no repouso — ${why()}');
        } else if (rest is ServiceOrderDetailState) {
          expect(rest.saving, isFalse, reason: 'saving preso no repouso — ${why()}');
          final id = rest.order.id;
          expect(rest.fiscal == null || rest.fiscal == voiceOf[id], isTrue, reason: 'voz de OUTRA OS no detalhe $id — ${why()}');
        }
        for (final s in states.whereType<ServiceOrderDetailState>()) {
          final id = s.order.id;
          expect((s.fiscal == null || s.fiscal == voiceOf[id]) && (s.effect == null || s.effect == effectOf[id]), isTrue,
              reason: 'detalhe $id emitido com a voz/efeito de OUTRA OS — ${why()}');
        }
        await sub.cancel();
        await bloc.close();
      }
      cover['savingDropped'] = savingDropped;
      // ignore: avoid_print
      print('cobertura do fuzz R12: $cover');
      // `savingDropped` = o R12-ADV-01 achado pelo PRÓPRIO fuzz (detalhe X sem saving com um ato de X nascido nesta tela no ar) — só
      // impresso: é o LIMITE CONHECIDO da D-F191 (b) (a prova dirigida é o teste R12-ADV-01 acima)
      const minimum = {'outcomeOnOwn': 500, 'outcomeElsewhere': 200, 'recreatedUnderDialog': 200, 'decisionAfterRecreate': 150,
          'chainAfterRecreate': 0, 'reopenedWithActInFlight': 8, 'sameNoteClickIgnored': 1, 'viewInAir': 50};
      for (final e in minimum.entries) {
        expect(cover[e.key] ?? 0, greaterThan(e.value), reason: 'o fuzz quase não exercitou "${e.key}": $cover');
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
