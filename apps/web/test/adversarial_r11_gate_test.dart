// GATE ADVERSARIAL independente do DELTA (correções dos gates do delta
// combinado + Rodada 11) da F2a/F2b (setes-app) — alvo: `3174d54..5983b29`
// (branch f2b): `_pendingDetailScreen` só morre onde o `_detail` nasce (ou na
// falha que volta à lista); `_stillOnDetail(screen)` + `_beginDetailAct`/
// `_endDetailAct` em todo ato no detalhe; `_reloadDetail(…, act: true)`;
// D-F179 (rotina mensal e "Transmitir pendentes" com trava de reentrância
// própria e no `_batchInFlight`), D-F180 (linha incerta: "ref" só do servidor;
// `CLIENT_*` só o código) e D-F181 (rede: "sem resposta do serviço — rede,
// proxy ou tempo"; chave `fiscalBatchNoResponse` pt/en).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R11-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r11_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre) — cada ACHADO
//     tem o seu FATO, que é a PROVA executável de hoje.
// Nada aqui fala com servidor: repositórios mocktail (molde dos gates R9/R10).
// O R11-ADV-01 deste gate é da nfse-api (`nfse-api/src/__tests__/adversarial-f2a-r11-gate.test.ts`).
//
// Valdo 2026-10-13 ("Q-F190 a Q-F194 - siga recomendações"): D-F182 (a MESMA OS reaberta é relida; o desfecho fora da OS leva o
// número dela), D-F183 (trava de duplo clique POR NOTA), D-F185 (a frase neutra no repositório da nfse-api) — as provas FATO viraram
// `[DECIDIDO …]` e os ACHADOS R11-ADV-02/03 rodam sempre (`[CORRIGIDO …]`).

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
import 'package:setes_web/app/modules/service_orders/data/datasource/service_order_nfse_datasource.dart';
import 'package:setes_web/app/modules/service_orders/data/repository/service_order_nfse_repository_impl.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _item = ServiceOrderItemInput(productId: 1, unitValue: 10);

/// A OS NOVA que o FAB abre (aberta) e duas OS FATURADAS (com a seção "No fisco": voz + efeito, DIFERENTES entre si).
const _newId = 77;
const _newOrder = ServiceOrderFull(id: _newId, customerId: 5);
const _aId = 7374;
const _a = ServiceOrderFull(id: _aId, customerId: 1, status: 'F');
const _bId = 8001;
const _b = ServiceOrderFull(id: _bId, customerId: 2, status: 'F');
const _aVoiceBefore = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 1);
const _aVoiceAfter = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 2);
const _bVoice = ServiceOrderFiscalView(state: NfseState.rejected, currentAttempt: 3);
const _aEffect = ServiceOrderFiscalEffect();
const _bEffect = ServiceOrderFiscalEffect(invoiceCancelled: true);

const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

PagedResult<ServiceOrderListItem> _page(List<int> ids) => PagedResult(
    items: [for (final id in ids) ServiceOrderListItem(id: id, customerId: 1)], page: 1, pageSize: 10, total: ids.length);

/// O que a TELA mostra: o último estado que o `buildWhen` da página deixa construir (lista ou detalhe).
ServiceOrderState _shown(List<ServiceOrderState> states) =>
    states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).last;

/// D-F185: o datasource da nfse-api (a borda HTTP) — para provar o repositório.
class _NfseDsMock extends Mock implements ServiceOrderNfseDatasource {}

/// Uma resposta EM VOO do fuzzer: a chamada fica parada até o agendador decidir (ok / falha).
class _Flight {
  _Flight(this.label, this.finish);
  final String label;
  final void Function(bool ok) finish;
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;
  late int listCalls;
  final pt = _load('pt');
  final en = _load('en');

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(_input);
    registerFallbackValue(_item);
    Localization.load(const Locale('pt'), translations: Translations(pt));
  });

  void listAnswersNow(List<int> ids) {
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async {
      listCalls++;
      return Right(_page(ids));
    });
  }

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    invoice = InvoiceRepoMock();
    listCalls = 0;
    listAnswersNow([1, 2]);
    when(() => repo.open(5)).thenAnswer((_) async => const Right(_newId));
    when(() => repo.getById(_newId)).thenAnswer((_) async => const Right(_newOrder));
    when(() => repo.getById(_aId)).thenAnswer((_) async => const Right(_a));
    when(() => repo.getById(_bId)).thenAnswer((_) async => const Right(_b));
    when(() => invoice.fiscalEffect(_aId)).thenAnswer((_) async => const Right(_aEffect));
    when(() => invoice.fiscalEffect(_bId)).thenAnswer((_) async => const Right(_bEffect));
    when(() => nfse.getView(_bId)).thenAnswer((_) async => const Right(_bVoice));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<(ServiceOrderBloc, List<ServiceOrderState>, StreamSubscription<ServiceOrderState>)> start() async {
    final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
    final states = <ServiceOrderState>[];
    final sub = bloc.stream.listen(states.add);
    return (bloc, states, sub);
  }

  // ---------------------------------------------------------------------
  // 1. R11-ADV-02 — o ato que MUDA a OS termina com a tela já em outro lugar
  //    que mostra a MESMA OS: nenhuma releitura
  // ---------------------------------------------------------------------
  group('R11-ADV-02 — o desfecho do ato × a MESMA OS na tela de agora', () {
    /// A voz de A muda quando a transmissão termina (o servidor autorizou).
    late ServiceOrderFiscalView aVoiceNow;
    late int aVoiceReads;
    setUp(() {
      aVoiceNow = _aVoiceBefore;
      aVoiceReads = 0;
      when(() => nfse.getView(_aId)).thenAnswer((_) async {
        aVoiceReads++;
        return Right(aVoiceNow);
      });
    });

    Future<Completer<Either<Failure, ServiceOrderTransmitResult>>> transmitThenReopenSame(
        ServiceOrderBloc bloc, List<ServiceOrderState> states) async {
      final transmit = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmit.future);
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));                               // o fisco demora (aluguel até 210 s)
      await pumpEventQueue();
      expect((_shown(states) as ServiceOrderDetailState).saving, isTrue);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página RECRIADA (cruzar 1100 px — D-F160)
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderListRequested(status: 'F'));                            // o operador volta à aba Faturadas…
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));                                   // …e reabre a MESMA OS (a voz de ANTES do ato)
      await pumpEventQueue(times: 20);
      final reopened = _shown(states) as ServiceOrderDetailState;
      expect([reopened.order.id, reopened.fiscal, reopened.saving], [_aId, _aVoiceBefore, false]);
      return transmit;
    }

    test('[DECIDIDO D-F182 — era o FATO do R11-ADV-02; agora a MESMA OS reaberta é RELIDA e o desfecho fora da OS leva o número dela] a correção do R10-ADV-03 (`_stillOnDetail` — o ato só relê se a tela que capturou AINDA é o detalhe) fecha a voz de OUTRA OS, mas também cala a releitura quando a tela de agora mostra a MESMA OS: "Transmitir" na OS A (o fisco demora), a página é recriada (resize) e o operador volta à aba Faturadas e REABRE a A — o GET da voz voltou ANTES do fim da transmissão (a voz de antes: recusada); a transmissão termina AUTORIZADA → o one-shot "NFS-e autorizada" aparece, mas a OS A na tela segue com a voz de ANTES (recusada, com o botão Transmitir) — nenhuma releitura. O mesmo no faturar (a lista recriada mostra a OS ainda em Abertas e nada a relê) e no cancelar OS', () async {
      final (bloc, states, sub) = await start();
      final transmit = await transmitThenReopenSame(bloc, states);
      final readsBefore = aVoiceReads;
      aVoiceNow = _aVoiceAfter;                                                          // o servidor gravou a autorização
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      final shown = _shown(states) as ServiceOrderDetailState;
      final authorized = states.whereType<ServiceOrderActionSuccess>().where((s) => s.messageKey == 'forms.serviceOrder.fiscalAuthorized');
      expect([authorized.length, authorized.single.orderNumber], [1, null], reason: 'a tela é a MESMA OS — sem prefixo');
      expect([shown.order.id, shown.fiscal, aVoiceReads > readsBefore], [_aId, _aVoiceAfter, true],
          reason: 'D-F182: a MESMA OS reaberta é RELIDA (a voz nova)');

      // o faturar: a lista recriada (Abertas) chega ANTES do fim do faturamento e segue mostrando a OS faturada
      final inv = Completer<Either<Failure, ServiceOrderInvoiceResult>>();
      when(() => repo.invoice(_newId, any())).thenAnswer((_) => inv.future);
      listAnswersNow([_newId, 1]);
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderInvoiceRequested(orderId: _newId, input: _input));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      final calls = listCalls;
      inv.complete(const Right(ServiceOrderInvoiceResult(invoiceNumber: '9001')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final list = _shown(states) as ServiceOrderListState;
      final generated = states.whereType<ServiceOrderActionSuccess>().where((s) => s.messageKey == 'forms.serviceOrder.invoiceGenerated');
      expect([generated.length, generated.single.orderNumber], [1, _newId], reason: 'D-F182: na LISTA, o desfecho leva o número da OS');
      // D-F182 deixou de fora a lista desatualizada (se corrige ao abrir a OS): ela não é relida
      expect([list.status, list.items.map((i) => i.id).contains(_newId), listCalls], ['A', true, calls]);
    });

    test('[CORRIGIDO R11-ADV-02 LOW — D-F182] o desfecho de um ato que MUDA a OS (transmitir, faturar, cancelar a OS ou a nota, item, manter a nota) relê a tela de AGORA quando ela mostra a MESMA OS (o detalhe reaberto: a voz nova; a lista: a recarga, respeitando o detalhe a caminho — D-F174) — "vale o último pedido" decide QUAL tela, não que ela fique com o dado de antes do ato. Correção sugerida: no fim do ato, se a tela capturada saiu mas `_detail?.id == orderId`, reler esse detalhe (pela geração de AGORA); se a tela é a lista e não há detalhe aberto/a caminho, recarregar a lista', () async {
      final (bloc, states, sub) = await start();
      final transmit = await transmitThenReopenSame(bloc, states);
      aVoiceNow = _aVoiceAfter;
      transmit.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 2, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final shown = _shown(states) as ServiceOrderDetailState;
      expect([shown.order.id, shown.fiscal], [_aId, _aVoiceAfter], reason: 'a OS A na tela com a voz relida (autorizada)');
    });
  });

  // ---------------------------------------------------------------------
  // 2. R11-ADV-03 — as travas GLOBAIS de duplo clique engolem o clique na
  //    OUTRA OS em silêncio
  // ---------------------------------------------------------------------
  group('R11-ADV-03 — `_transmitting`/`_invoiceCancelling` × a OUTRA OS', () {
    test('[DECIDIDO D-F183 — era o FATO do R11-ADV-03; a trava agora é POR NOTA: o clique na OUTRA OS vai, e o desfecho da A sobre a B leva o número da A (D-F182)] as travas de duplo clique do Transmitir (`_transmitting` — F2B-ADV-07) e do cancelamento/manter a nota (`_invoiceCancelling`) são do BLOC, não da nota: com a transmissão da OS A em voo (o fisco segura até 210 s) e a página recriada, o operador abre a OS B (recusada) e clica "Transmitir" — o clique é IGNORADO em silêncio: nenhum pedido à nfse-api, nenhum `saving`, nenhum aviso (o botão parece morto). O mesmo com "Cancelar nota" (saga) em voo na A e "Manter a nota" na B. A correção do R10-ADV-03 tornou explícito que o ato SOBREVIVE à tela — e a trava sobrevive com ele', () async {
      final transmitA = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoiceBefore));
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmitA.future);
      when(() => nfse.transmit(_bId)).thenAnswer((_) async => const Right(ServiceOrderTransmitResult(invoiceId: _bId, attempt: 4, accessKey: 'KB')));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));
      await pumpEventQueue(times: 20);
      final at = states.length;
      bloc.add(const ServiceOrderTransmitRequested(_bId));                               // o clique na OS B
      await pumpEventQueue(times: 20);
      verify(() => nfse.transmit(_bId)).called(1);                                       // D-F183: o clique da OUTRA nota vai
      expect(states.sublist(at).whereType<ServiceOrderDetailState>().any((s) => s.saving), isTrue);
      final atA = states.length;
      transmitA.complete(const Left(Failure(message: 'x', statusCode: 422, code: 'FISCAL_DPS_REJECTED')));
      await pumpEventQueue(times: 20);
      // D-F182: a recusa da A chega com a B na tela — leva o número da A
      expect(states.sublist(atA).whereType<ServiceOrderActionFailure>().single.orderNumber, _aId);

      // o cancelamento (saga sem o fisco) em voo na A × "Manter a nota" na B
      final localCancel = Completer<Either<Failure, ServiceOrderInvoiceCancelResult>>();
      when(() => invoice.cancel(_aId, any())).thenAnswer((_) => localCancel.future);
      when(() => invoice.cancelWaiver(_bId, any())).thenAnswer((_) async => const Right(ServiceOrderCancelWaiverResult(orderId: _bId)));
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderCancelConfirmed(orderId: _aId, reason: 'motivo', atAuthority: false));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalCancelWaiverRequested(orderId: _bId, reason: 'manter'));
      await pumpEventQueue(times: 20);
      verify(() => invoice.cancelWaiver(_bId, any())).called(1);                        // D-F183: a decisão sobre OUTRA nota vai
      localCancel.complete(const Left(Failure(message: 'x', statusCode: 409)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
    });

    test('[CORRIGIDO R11-ADV-03 LOW — D-F183] o clique num ato da OUTRA OS nunca some em silêncio: ou vai (a trava da NOTA na nfse-api/ERP barra o duplo envio da mesma nota — a trava do bloc é só o duplo clique da MESMA nota), ou o operador lê por quê. Correção sugerida: a trava de duplo clique POR NOTA (`Set<int>` com o orderId) — ou um aviso "outra transmissão em andamento"', () async {
      final transmitA = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoiceBefore));
      when(() => nfse.transmit(_aId)).thenAnswer((_) => transmitA.future);
      var sent = 0;
      when(() => nfse.transmit(_bId)).thenAnswer((_) async {
        sent++;
        return const Right(ServiceOrderTransmitResult(invoiceId: _bId, attempt: 4, accessKey: 'KB'));
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_bId));
      await pumpEventQueue(times: 20);
      final at = states.length;
      bloc.add(const ServiceOrderTransmitRequested(_bId));
      await pumpEventQueue(times: 20);
      final told = states.sublist(at).any((s) => s is ServiceOrderActionFailure || s is ServiceOrderFiscalNotice || s is ServiceOrderActionSuccess);
      transmitA.complete(const Left(Failure(message: 'x', statusCode: 422)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(sent > 0 || told, isTrue);
    });

    test('D-F183: o 2º clique na MESMA nota com a 1ª transmissão no ar segue IGNORADO (a trava por nota é a do duplo clique)', () async {
      final transmitA = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoiceBefore));
      var sent = 0;
      when(() => nfse.transmit(_aId)).thenAnswer((_) {
        sent++;
        return transmitA.future;
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue(times: 20);
      expect(sent, 1);
      transmitA.complete(const Left(Failure(message: 'x', statusCode: 422)));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));                               // a trava soltou: o próximo clique vai
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(sent, 2);
    });
  });

  // ---------------------------------------------------------------------
  // 3. Q-F190-ADV-04 — D-F181 só na LINHA do lote: o ato avulso diz a
  //    frase de conexão
  // ---------------------------------------------------------------------
  group('D-F181 × o ato avulso', () {
    test('[DECIDIDO D-F185 — o repositório da nfse-api troca a mensagem da NetworkFailure pela frase NEUTRA (o tipo e o ref seguem); o bloc com repositório falso (abaixo) segue recebendo a falha CRUA — a prova do repositório é o teste seguinte] era o FATO do R11-ADV-04: a frase NEUTRA da D-F181 valia só na linha do lote: o ATO avulso (Transmitir/Reconferir/Cancelar no fisco) com a MESMA falha — a página 502/504 do proxy sem CORS no app WEB, que chega como `NetworkFailure` (R10-ADV-04) — mostra "O fisco não deu uma resposta conclusiva…" + "Falha de conexão com o servidor" (`core.errors.network`): a frase de conexão que a D-F181 tirou da linha', () async {
      when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoiceBefore));
      when(() => nfse.transmit(_aId)).thenAnswer((_) async =>
          const Left(NetworkFailure(detail: 'ClientException: XMLHttpRequest error., uri=https://nfse.setes.example/v1/nfse/invoices/7374/transmit')));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderTransmitRequested(_aId));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final notice = states.whereType<ServiceOrderFiscalNotice>().single;
      expect([notice.messageKey, notice.detail], ['forms.serviceOrder.fiscalOutcomeUnknown', 'core.errors.network']);
      expect(notice.detail!.tr(), 'Falha de conexão com o servidor');
      // a chave neutra da LINHA do lote segue com UM uso na página
      final uses = RegExp('fiscalBatchNoResponse').allMatches(File(_pageSrc).readAsStringSync()).length;
      expect(uses, 1);
    });

    test('D-F185: o repositório da nfse-api (todas as chamadas à nfse-api — os atos fiscais e a voz da seção "No fisco") devolve a falta de resposta com a frase NEUTRA; o tipo (NetworkFailure: desfecho desconhecido num ato, linha "rede" no lote) e o ref seguem', () async {
      final ds = _NfseDsMock();
      when(() => ds.transmit(_aId)).thenThrow(const NetworkFailure(detail: 'ClientException: XMLHttpRequest error.'));
      when(() => ds.getView(_aId)).thenThrow(const NetworkFailure());
      final repo = ServiceOrderNfseRepositoryImpl(datasource: ds);
      for (final r in [await repo.transmit(_aId), await repo.getView(_aId)]) {
        final f = r.fold((f) => f, (_) => null)!;
        expect([f is NetworkFailure, f.message, isUnknownAuthorityOutcome(f)], [true, 'forms.serviceOrder.fiscalNoResponse', true]);
      }
      final f = (await repo.transmit(_aId)).fold((f) => f, (_) => null)!;
      expect(f.supportRef, 'ClientException: XMLHttpRequest error.');
      for (final lang in ['pt', 'en']) {
        final j = jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;
        expect(((j['forms'] as Map)['serviceOrder'] as Map)['fiscalNoResponse'], isA<String>());
      }
      expect('forms.serviceOrder.fiscalNoResponse'.tr(), 'Sem resposta do serviço — rede, proxy ou tempo.');
    });
  });

  // ---------------------------------------------------------------------
  // 4. D-F180 / D-F181 — o que RESISTIU
  // ---------------------------------------------------------------------
  group('D-F180/D-F181 — a linha do lote × todos os tipos de Failure', () {
    Future<FiscalTransmitBatchReport> batch(Map<int, Failure> by) {
      when(() => nfse.transmit(any())).thenAnswer((inv) async => Left(by[inv.positionalArguments[0] as int]!));
      return ServiceOrderFiscalTransmitBatch(repository: nfse, maxConsecutiveUnknown: 99).call(by.keys.toList());
    }

    /// As linhas como a PÁGINA as compõe (`_showFiscalBatchSummary` — a cerca do fonte abaixo).
    List<String> lines(FiscalTransmitBatchReport report) => [
          for (final r in report.uncertainRows)
            'forms.serviceOrder.fiscalBatchUncertainRow'.tr(args: ['${r.orderId}']) +
                (r.network ? ' (${'forms.serviceOrder.fiscalBatchNoResponse'.tr()})' : r.uncertainDetail),
          for (final r in report.refusedRows)
            'forms.serviceOrder.fiscalBatchRefusedRow'.tr(args: ['${r.orderId}', [r.code, r.message.tr()].where((s) => s.isNotEmpty).join(' — ')]),
          for (final r in report.notTriedRows) 'forms.serviceOrder.fiscalBatchNotTriedRow'.tr(args: ['${r.orderId}']),
        ];

    test('[RESISTIU] D-F180 com TODA falha que o app monta: `SESSION_NOT_ACCEPTED` (montada pelo app SEM o prefixo `CLIENT_`, com a frase de ORIGEM do servidor no supportRef) e `CLIENT_CONFIGURATION` (a URL no supportRef) são SISTÊMICAS — linha RECUSADA (que nunca imprime o supportRef) e o lote para; `invalidResponseFailure` (texto do Dart) e o envelope estrito (2xx fora do `{ok:true}`, com o status) = incerta só com o código; `NetworkFailure` (com o texto da exceção) = a frase neutra; o ref do SERVIDOR segue (500 INTERNAL, 409 RESOURCE_BUSY, 503 FISCAL_AUTHORITY_UNAVAILABLE). Nenhuma linha leva texto do Dart, URL, exceção ou "()"', () async {
      final r = await batch({
        1: invalidResponseFailure("type 'Null' is not a subtype of type 'String' in type cast"),
        2: const Failure(message: 'core.errors.invalidResponse', statusCode: 200, code: ClientFailureCodes.invalidResponse),
        3: const NetworkFailure(detail: 'ClientException: XMLHttpRequest error., uri=https://nfse.setes.example/v1/x'),
        4: const Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'srv500'),
        5: const Failure(message: 'em uso', statusCode: 409, code: 'RESOURCE_BUSY', supportRef: 'srv409'),
        6: const Failure(message: 'fisco fora', statusCode: 503, code: 'FISCAL_AUTHORITY_UNAVAILABLE', supportRef: 'srv503'),
        7: const Failure(message: 'core.errors.sessionNotAccepted', statusCode: 401, code: ClientFailureCodes.sessionNotAccepted,
            supportRef: 'FISCAL_AUTH_KID_UNKNOWN: kid desconhecido kid-9f'),
        8: const Failure(message: 'x', statusCode: 422),
      });
      final byId = {for (final row in r.rows) row.orderId: row};
      expect(r.uncertainRows.map((x) => x.orderId).toList(), [1, 2, 3, 4, 5, 6]);
      expect([for (final id in [1, 2, 4, 5, 6]) byId[id]!.uncertainDetail], [
        ' (CLIENT_INVALID_RESPONSE)', ' (CLIENT_INVALID_RESPONSE)', ' (INTERNAL · ref srv500)', ' (RESOURCE_BUSY · ref srv409)',
        ' (FISCAL_AUTHORITY_UNAVAILABLE · ref srv503)',
      ]);
      expect([r.refused, r.notTried, r.stoppedBy?.code], [1, 1, ClientFailureCodes.sessionNotAccepted]);
      final all = lines(r).join('\n');
      for (final leak in ["type 'Null'", 'XMLHttpRequest', 'ClientException', 'https://', 'kid-9f', '()', 'ref FISCAL_AUTH']) {
        expect(all.contains(leak), isFalse, reason: '"$leak" vazou: $all');
      }
      final config = await batch({1: const Failure(message: 'core.errors.configuration', code: ClientFailureCodes.configuration, supportRef: 'https://cfg-xyz.invalid'),
          2: const Failure(message: 'x', statusCode: 503)});
      expect([config.refused, config.notTried, lines(config).join().contains('cfg-xyz')], [1, 1, false]);
      // a página compõe a recusada SÓ com código + mensagem (nunca o supportRef) — a cerca do fonte
      expect(File(_pageSrc).readAsStringSync(), contains(r"[r.code, r.message.tr()].where((s) => s.isNotEmpty).join(' — '),"));
    });

    test('[RESISTIU] D-F181 nas DUAS línguas: a chave nova existe em pt e en com o texto decidido, a antiga (`fiscalBatchNoConnection`) sumiu das duas, nenhum valor de tradução da família `fiscalBatch*` diz "sem conexão"/"no connection", e a linha em inglês sai com a frase inglesa', () async {
      Map<String, dynamic> so(Map<String, dynamic> lang) => (lang['forms'] as Map<String, dynamic>)['serviceOrder'] as Map<String, dynamic>;
      expect(so(pt)['fiscalBatchNoResponse'], 'sem resposta do serviço — rede, proxy ou tempo');
      expect(so(en)['fiscalBatchNoResponse'], 'no response from the service — network, proxy or timeout');
      for (final lang in [pt, en]) {
        expect(so(lang).containsKey('fiscalBatchNoConnection'), isFalse);
        for (final e in so(lang).entries.where((e) => e.key.startsWith('fiscalBatch'))) {
          expect('${e.value}'.toLowerCase(), isNot(anyOf(contains('sem conexão'), contains('no connection'))), reason: e.key);
        }
      }
      expect(so(pt).keys.where((k) => k.startsWith('fiscalBatch')).toSet(), so(en).keys.where((k) => k.startsWith('fiscalBatch')).toSet(),
          reason: 'as duas línguas com as MESMAS chaves do lote');
      Localization.load(const Locale('en'), translations: Translations(en));
      try {
        final r = await batch({1: const NetworkFailure()});
        expect(lines(r).single, endsWith(' (no response from the service — network, proxy or timeout)'));
      } finally {
        Localization.load(const Locale('pt'), translations: Translations(pt));
      }
    });
  });

  // ---------------------------------------------------------------------
  // 5. D-F179 — sequências que RESISTIRAM
  // ---------------------------------------------------------------------
  group('D-F179 — a trava H1 completa', () {
    test('[RESISTIU] a rotina mensal no ar: a página recriada (lista em loading), o FAB abre a OS no meio, "voltar" devolve a lista AINDA em loading (a rotina segue), o 2º disparo não vai ao servidor; a rotina FALHA (403) → a falha vai à ponte e a lista volta LIVRE; um novo disparo depois VAI (a trava não ficou presa)', () async {
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      var runs = 0;
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) {
        runs++;
        return runs == 1 ? run.future : Future.value(const Right(MonthlyRunReport(processed: 1)));
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));                // a página recriada
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue);
      bloc.add(const ServiceOrderOpenRequested(5));                                       // o FAB
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderDetailState).order.id, _newId);
      bloc.add(const ServiceOrderBackToListPressed());
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue, reason: 'a rotina segue — a lista segue travada');
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue(times: 20);
      expect(runs, 1);
      run.complete(const Left(Failure(message: 'Sem privilégio', statusCode: 403)));
      await pumpEventQueue(times: 20);
      expect([states.whereType<ServiceOrderActionFailure>().length, (_shown(states) as ServiceOrderListState).loading], [1, false]);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect([runs, states.whereType<ServiceOrderMonthlyRunDone>().length, (_shown(states) as ServiceOrderListState).loading], [2, 1, false]);
    });

    test('[RESISTIU] a fotografia das pendentes FALHA (rede) com a lista recriada no meio: a lista volta LIVRE e a trava solta (a 2ª fotografia vai); com o lote fiscal no ar, a fotografia é recusada no bloc (sem 2º diálogo); o módulo FECHADO no meio da rotina mensal não lança nada nem emite (as travas são do bloc que morre com o módulo)', () async {
      var asks = 0;
      final first = Completer<Either<Failure, PagedResult<ServiceOrderFiscalPending>>>();
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((_) {
        asks++;
        return asks == 1 ? first.future : Future.value(const Right(PagedResult(items: [], page: 1, pageSize: 100, total: 0)));
      });
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F'));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isTrue);
      first.complete(const Left(NetworkFailure()));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue(times: 20);
      expect(asks, 2);
      // o lote fiscal no ar barra a fotografia
      final gate = Completer<Either<Failure, ServiceOrderTransmitResult>>();
      when(() => nfse.transmit(_aId)).thenAnswer((_) => gate.future);
      bloc.add(const ServiceOrderFiscalTransmitBatchRequested([_aId]));
      await pumpEventQueue();
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await pumpEventQueue(times: 20);
      expect(asks, 2);
      gate.complete(const Right(ServiceOrderTransmitResult(invoiceId: _aId, attempt: 1, accessKey: 'K')));
      await pumpEventQueue(times: 20);
      expect((_shown(states) as ServiceOrderListState).loading, isFalse);
      // o módulo fecha no meio da rotina mensal
      final run = Completer<Either<Failure, MonthlyRunReport>>();
      when(() => repo.monthlyRun(2026, 10)).thenAnswer((_) => run.future);
      bloc.add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
      await pumpEventQueue();
      final at = states.length;
      bloc.stopBatches();
      await bloc.close();
      run.complete(const Right(MonthlyRunReport(processed: 1)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      expect(states.length, at, reason: 'nada emitido depois do fechamento');
    });

    test('[RESISTIU] a falha de um ato com a MESMA OS reaberta no meio não volta por cima dela nem prende o `saving`: "Consultar" na A, a página recriada, a A reaberta (detalhe novo, sem saving); a consulta falha (409) → só o one-shot; a A reaberta fica como está e o próximo "Consultar" marca saving e vai', () async {
      when(() => nfse.getView(_aId)).thenAnswer((_) async => const Right(_aVoiceBefore));
      final first = Completer<Either<Failure, ServiceOrderFiscalRefreshResult>>();
      var refreshes = 0;
      when(() => nfse.refresh(_aId)).thenAnswer((_) => ++refreshes == 1 ? first.future : Future.value(const Right(ServiceOrderFiscalRefreshResult())));
      final (bloc, states, sub) = await start();
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
      await pumpEventQueue();
      bloc.add(const ServiceOrderListRequested(status: 'F', filter: ''));
      await pumpEventQueue(times: 20);
      bloc.add(const ServiceOrderViewRequested(_aId));
      await pumpEventQueue(times: 20);
      final at = states.length;
      first.complete(const Left(Failure(message: 'em uso', statusCode: 409, code: 'RESOURCE_BUSY')));
      await pumpEventQueue(times: 20);
      expect(states.sublist(at).whereType<ServiceOrderDetailState>(), isEmpty);
      expect(states.sublist(at).whereType<ServiceOrderActionFailure>(), hasLength(1));
      bloc.add(const ServiceOrderFiscalRefreshRequested(_aId));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(refreshes, 2);
      expect(states.whereType<ServiceOrderDetailState>().where((s) => s.saving).length, 2);
      expect((_shown(states) as ServiceOrderDetailState).saving, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  // 6. FUZZ — interleavings aleatórios (o operador como a página permite +
  //    respostas em qualquer ordem, com falhas) — invariantes no repouso
  // ---------------------------------------------------------------------
  group('fuzz do bloc — 400 sementes', () {
    test('[RESISTIU] em 400 sequências aleatórias (ver/abrir/voltar/aba, página recriada a qualquer momento, atos no detalhe — item, faturar, cancelar OS, transmitir, consultar, XML, plano, manter a nota —, rotina mensal, pendentes → lote fiscal, lote de faturamento; cada resposta em ordem aleatória, ~25 % falhas): no REPOUSO (nada em voo) a tela nunca fica no spinner nem com `saving`; o detalhe mostrado tem a voz e o efeito DA SUA OS (nunca de outra); e as travas soltam (a rotina mensal, a fotografia, o lote de faturamento e a transmissão vão ao servidor de novo)', () async {
      const voiceOf = {_aId: _aVoiceBefore, _bId: _bVoice};
      const effectOf = {_aId: _aEffect, _bId: _bEffect};
      const orderOf = {_newId: _newOrder, _aId: _a, _bId: _b};
      final cover = <String, int>{};
      for (var seed = 1; seed <= 400; seed++) {
        final rnd = Random(seed);
        final flights = <_Flight>[];
        final trace = <String>[];
        Failure fail() => rnd.nextBool() ? const Failure(message: 'x', statusCode: 500) : const NetworkFailure();
        Future<Either<Failure, T>> park<T>(String label, T Function() ok) {
          final c = Completer<Either<Failure, T>>();
          flights.add(_Flight(label, (good) => c.complete(good ? Right(ok()) : Left(fail()))));
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
        for (final id in voiceOf.keys) {
          when(() => nfse.getView(id)).thenAnswer((_) => park('voice $id', () => voiceOf[id]!));
          when(() => invoice.fiscalEffect(id)).thenAnswer((_) => park('effect $id', () => effectOf[id]!));
          when(() => nfse.refresh(id)).thenAnswer((_) => park('refresh $id', () => const ServiceOrderFiscalRefreshResult()));
          when(() => nfse.xml(id)).thenAnswer((_) => park('xml $id', () => '<x/>'));
          when(() => invoice.cancelPlan(id)).thenAnswer((_) => park('plan $id', () => ServiceOrderCancelPlan(orderId: id)));
          when(() => invoice.cancelWaiver(id, any())).thenAnswer((_) => park('waiver $id', () => ServiceOrderCancelWaiverResult(orderId: id)));
        }
        when(() => nfse.transmit(any())).thenAnswer((inv) {
          final id = inv.positionalArguments[0] as int;
          return park('transmit $id', () => ServiceOrderTransmitResult(invoiceId: id, attempt: 1, accessKey: 'K'));
        });
        when(() => repo.open(5)).thenAnswer((_) => park('post', () => _newId));
        when(() => repo.itemPost(_newId, any())).thenAnswer((_) => park('item', () => 1));
        when(() => repo.invoice(_newId, any())).thenAnswer((_) => park('invoice', () => const ServiceOrderInvoiceResult(invoiceNumber: '1')));
        when(() => repo.cancel(_newId)).thenAnswer((_) => park('cancelOs', () => unit));
        when(() => repo.monthlyRun(any(), any())).thenAnswer((_) => park('monthly', () => const MonthlyRunReport(processed: 1)));
        when(() => repo.batchInvoice(any(), any())).thenAnswer((_) => park('batch', () => BatchInvoiceReport.fromEntries(const [BatchInvoiceEntry(orderId: _newId, ok: true)])));
        when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
            .thenAnswer((_) => park('pending', () => const PagedResult(items: [ServiceOrderFiscalPending(invoiceId: _aId)], page: 1, pageSize: 100, total: 1)));

        final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
        final states = <ServiceOrderState>[];
        var pendingSeen = 0;
        final sub = bloc.stream.listen(states.add);
        void add(ServiceOrderEvent e) {
          trace.add('${e.runtimeType}${e.props}');
          bloc.add(e);
        }

        Future<void> completeOne({double okRate = 0.75}) async {
          final f = flights.removeAt(rnd.nextInt(flights.length));
          final ok = rnd.nextDouble() < okRate;
          trace.add('<- ${f.label} ${ok ? 'ok' : 'FAIL'}');
          f.finish(ok);
          await pumpEventQueue();
        }

        add(const ServiceOrderListRequested(status: 'A', filter: ''));                 // o initState
        await pumpEventQueue();
        for (var step = 0; step < 80; step++) {
          if (flights.isNotEmpty && rnd.nextDouble() < 0.5) {
            await completeOne();
            continue;
          }
          // a confirmação do "Transmitir pendentes" abre por cima de QUALQUER tela (o listener da página)
          final loaded = states.whereType<ServiceOrderFiscalPendingLoaded>().length;
          if (loaded > pendingSeen) {
            pendingSeen = loaded;
            if (rnd.nextBool()) add(const ServiceOrderFiscalTransmitBatchRequested([_aId]));
            await pumpEventQueue();
            continue;
          }
          final shown = states.where((s) => s is ServiceOrderListState || s is ServiceOrderDetailState).lastOrNull;
          final pick = rnd.nextInt(100);
          // página recriada (resize — D-F160): a QUALQUER momento; mais provável com o ato no ar (o caso que a correção do R10 mexeu)
          final recreate = shown is ServiceOrderDetailState && shown.saving ? pick < 40 : pick < 6;
          if (recreate) {
            if (shown is ServiceOrderDetailState && shown.saving) cover['recreatedWhileSaving'] = (cover['recreatedWhileSaving'] ?? 0) + 1;
            if (shown is ServiceOrderListState && shown.loading) cover['recreatedWhileLoading'] = (cover['recreatedWhileLoading'] ?? 0) + 1;
            add(const ServiceOrderListRequested(status: 'A', filter: ''));
          } else if (shown is ServiceOrderDetailState) {
            if (shown.saving) {
              // botões travados — esperar
            } else if (pick < 18) {
              add(const ServiceOrderBackToListPressed());
            } else if (shown.order.isOpen) {
              final acts = <ServiceOrderEvent>[
                const ServiceOrderItemSaveRequested(orderId: _newId, input: _item),
                const ServiceOrderInvoiceRequested(orderId: _newId, input: _input),
                const ServiceOrderCancelRequested(_newId),
              ];
              add(acts[rnd.nextInt(acts.length)]);
            } else {
              final id = shown.order.id;
              final acts = <ServiceOrderEvent>[
                ServiceOrderTransmitRequested(id),
                ServiceOrderFiscalRefreshRequested(id),
                ServiceOrderFiscalXmlRequested(id),
                ServiceOrderCancelFlowRequested(id),
                ServiceOrderFiscalCancelWaiverRequested(orderId: id, reason: 'manter'),
              ];
              add(acts[rnd.nextInt(acts.length)]);
            }
          } else if (shown is ServiceOrderListState) {
            if (shown.loading) {
              // no spinner: aba/filtro e o FAB seguem ativos (ou esperar)
              if (pick < 35) {
                add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
              } else if (pick < 65) {
                add(const ServiceOrderOpenRequested(5));
              }
            } else if (pick < 50) {
              add(ServiceOrderViewRequested([_aId, _bId, _aId, _bId, _newId][rnd.nextInt(5)]));
            } else if (pick < 60) {
              add(const ServiceOrderOpenRequested(5));
            } else if (pick < 68) {
              add(ServiceOrderListRequested(status: rnd.nextBool() ? 'A' : 'F'));
            } else if (pick < 79) {
              add(const ServiceOrderMonthlyRunRequested(year: 2026, month: 10));
            } else if (pick < 90) {
              add(const ServiceOrderFiscalPendingRequested());
            } else {
              add(const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input));
            }
          }
          await pumpEventQueue();
        }

        Future<void> drain() async {
          for (var guard = 0; flights.isNotEmpty; guard++) {
            expect(guard, lessThan(3000), reason: 'seed $seed não drena');
            await completeOne(okRate: 0.85);
          }
          await pumpEventQueue(times: 20);
        }

        await drain();
        String why() => 'seed $seed\n${trace.join('\n')}';
        void assertRest() {
          final shown = _shown(states);
          if (shown is ServiceOrderListState) {
            expect(shown.loading, isFalse, reason: 'spinner preso no repouso — ${why()}');
          } else if (shown is ServiceOrderDetailState) {
            expect(shown.saving, isFalse, reason: 'saving preso no repouso — ${why()}');
            final id = shown.order.id;
            expect(shown.fiscal == null || shown.fiscal == voiceOf[id], isTrue, reason: 'voz de OUTRA OS no detalhe $id — ${why()}');
            expect(shown.effect == null || shown.effect == effectOf[id], isTrue, reason: 'efeito de OUTRA OS no detalhe $id — ${why()}');
            if (!shown.order.isOpen) {
              expect(shown.fiscal != null || shown.fiscalFailure != null, isTrue, reason: 'detalhe faturado sem a voz nem a falha dela — ${why()}');
            }
          }
        }

        assertRest();
        // as travas soltaram: cada operação longa vai ao servidor de novo; a transmissão também
        if (_shown(states) is ServiceOrderDetailState) {
          add(const ServiceOrderBackToListPressed());
          await pumpEventQueue();
          await drain();
        }
        for (final (event, label) in [
          (const ServiceOrderMonthlyRunRequested(year: 2026, month: 10), 'monthly'),
          (const ServiceOrderFiscalPendingRequested(), 'pending'),
          (const ServiceOrderBatchInvoiceRequested(orderIds: [_newId], input: _input), 'batch'),
        ]) {
          add(event);
          await pumpEventQueue();
          expect(flights.any((f) => f.label == label), isTrue, reason: 'a trava de "$label" ficou PRESA — ${why()}');
          await drain();
          assertRest();
        }
        add(const ServiceOrderViewRequested(_bId));
        await pumpEventQueue();
        while (flights.isNotEmpty) {
          final f = flights.removeAt(0);
          f.finish(true);
          await pumpEventQueue();
        }
        await pumpEventQueue(times: 20);
        add(const ServiceOrderTransmitRequested(_bId));
        await pumpEventQueue();
        expect(flights.any((f) => f.label == 'transmit $_bId'), isTrue, reason: 'a trava do Transmitir ficou PRESA — ${why()}');
        await drain();
        assertRest();
        // EM TODO estado emitido (não só no repouso): o detalhe nunca leva a voz/efeito de outra OS
        for (final s in states.whereType<ServiceOrderDetailState>()) {
          final id = s.order.id;
          expect((s.fiscal == null || s.fiscal == voiceOf[id]) && (s.effect == null || s.effect == effectOf[id]), isTrue,
              reason: 'detalhe $id emitido com a voz/efeito de OUTRA OS — ${why()}');
        }
        // cobertura (o fuzz exercitou o que diz exercitar)
        cover['saving'] = (cover['saving'] ?? 0) + states.whereType<ServiceOrderDetailState>().where((s) => s.saving).length;
        cover['monthlyDone'] = (cover['monthlyDone'] ?? 0) + states.whereType<ServiceOrderMonthlyRunDone>().length;
        cover['fiscalBatchDone'] = (cover['fiscalBatchDone'] ?? 0) + states.whereType<ServiceOrderFiscalBatchDone>().length;
        cover['invoiceBatchDone'] = (cover['invoiceBatchDone'] ?? 0) + states.whereType<ServiceOrderBatchInvoiceDone>().length;
        cover['planReady'] = (cover['planReady'] ?? 0) + states.whereType<ServiceOrderCancelPlanReady>().length;
        cover['notices'] = (cover['notices'] ?? 0) + states.whereType<ServiceOrderFiscalNotice>().length;
        cover['failures'] = (cover['failures'] ?? 0) + states.whereType<ServiceOrderActionFailure>().length;
        await sub.cancel();
        await bloc.close();
      }
      // ignore: avoid_print
      print('cobertura do fuzz: $cover');
      const minimum = {'saving': 300, 'recreatedWhileSaving': 100, 'recreatedWhileLoading': 300, 'monthlyDone': 200, 'fiscalBatchDone': 50,
          'invoiceBatchDone': 200, 'planReady': 10, 'notices': 30, 'failures': 500};
      for (final e in minimum.entries) {
        expect(cover[e.key] ?? 0, greaterThan(e.value), reason: 'o fuzz quase não exercitou "${e.key}": $cover');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
