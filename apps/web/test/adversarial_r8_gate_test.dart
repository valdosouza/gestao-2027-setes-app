// GATE ADVERSARIAL do DELTA da Rodada 8 da F2a/F2b (setes-app) — alvo: commit
// 13cdd92 (delta sobre e89231e): D-F171 ("não tentadas" com contador e linha
// próprios no relatório do lote fiscal), a parada por incertas seguidas com
// frase própria, a linha incerta com código e `supportRef` (R7-SOC-02) e o
// contador de GERAÇÃO do `_reloadList` (R7-SOC-03 — recarga superada não emite).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R8-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r8_gate_test.dart
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail. A frase da página
// (`_showFiscalBatchSummary`, privada) é composta aqui pela MESMA expressão —
// conferida contra o fonte por regex (molde do gate R7).

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
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

import 'support/service_order_bloc_factory.dart';

const _input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
const _tx = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');
const _proxy503 = Failure(message: 'Service Unavailable', statusCode: 503);   // nginx/Plesk na frente da nfse-api: HTML, sem code/ref
const _proxy502 = Failure(message: 'Bad Gateway', statusCode: 502);
const _bare500 = Failure(message: 'core.errors.generic', statusCode: 500);   // 500 sem corpo da casa
const _internal = Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'ab12cd');

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

MenuInterface _iface(List<String> privileges) => MenuInterface(id: 1, description: 'service-orders', privileges: privileges);

const _pageSrc = 'lib/app/modules/service_orders/presentation/page/service_order_page.dart';

ServiceOrderListItem _item(int id, {String status = 'A'}) => ServiceOrderListItem(id: id, customerId: 1, status: status);
PagedResult<ServiceOrderListItem> _page(List<int> ids, {String status = 'A', int page = 1, int total = -1}) =>
    PagedResult(items: [for (final id in ids) _item(id, status: status)], page: page, pageSize: 10, total: total < 0 ? ids.length : total);

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;
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
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
        .thenAnswer((_) async => const Right(PagedResult.empty()));
    CurrentInterface.value = _iface(['TRANSMITIR', 'CANCELAR', 'FATURAR']);
  });
  tearDown(() => CurrentInterface.value = null);

  Future<FiscalTransmitBatchReport> usecase(Map<int, Either<Failure, ServiceOrderTransmitResult>> by, List<int> ids) {
    when(() => nfse.transmit(any())).thenAnswer((inv) async => by[inv.positionalArguments[0] as int]!);
    return ServiceOrderFiscalTransmitBatch(repository: nfse).call(ids);
  }

  // ---------------------------------------------------------------------
  // 1. D-F171 + R7-SOC-02 — o relatório do lote fiscal
  // ---------------------------------------------------------------------
  group('D-F171 / R7-SOC-02 — o relatório em todas as combinações', () {
    test('[CORRIGIDO R8-ADV-03 LOW — R8-SOC-02 (a)] a linha INCERTA ganhou "({código · ref})" (R7-SOC-02 iii), mas a falha que mais vira "incerta" — o PROXY na frente da nfse-api (502/503/504 com página HTML: sem `code` nem `ref`) e o 500 sem corpo da casa — não tem nenhum dos dois: a frase termina com "()" VAZIO ("Ordem 1: resultado incerto — consulte a situação no fisco antes de transmitir de novo ()"). O certo: sem código e sem ref, nada de parênteses (ou o status HTTP no lugar)', () async {
      final r = await usecase({1: const Left(_proxy503), 2: const Left(_proxy502), 3: const Left(_bare500)}, [1, 2, 3]);
      final src = File(_pageSrc).readAsStringSync();
      // D-F176: a página compõe a linha com "sem conexão" (rede) ou o complemento (código · ref · HTTP)
      expect(src, contains(r"'forms.serviceOrder.fiscalBatchUncertainRow'.tr(args: ['${r.orderId}']) +"));
      expect(src, contains(r"(r.network ? ' (${'forms.serviceOrder.fiscalBatchNoConnection'.tr()})' : r.uncertainDetail)"));
      for (final row in r.uncertainRows) {
        final line = 'forms.serviceOrder.fiscalBatchUncertainRow'.tr(args: ['${row.orderId}']) + row.uncertainDetail;
        expect(line, isNot(contains('()')), reason: line);
      }
    });

    test('[CORRIGIDO — era o FATO base do R8-ADV-03] 503/502 do proxy e 500 sem corpo = 3 incertas (D-F168, certo) e as 3 linhas SEM complemento (nada de "()"); a rede caída (NetworkFailure) mostra "(ref ClientException…)" — o `supportRef` da rede é o TEXTO da exceção (R2), não um código de suporte; o 500 da casa mostra "(INTERNAL · ref ab12cd)"', () async {
      final r = await usecase({
        1: const Left(_proxy503), 2: const Left(_proxy502), 3: const Left(_bare500),
      }, [1, 2, 3]);
      expect([r.uncertain, r.refused, r.notTried], [3, 0, 0]);
      // D-F176 (= Q-F184 (b)): sem código da casa, o STATUS HTTP (o suporte sabe que foi o proxy); nunca "()"
      expect(r.uncertainRows.map((row) => row.uncertainDetail).toList(), [' (HTTP 503)', ' (HTTP 502)', ' (HTTP 500)']);
      final net = await usecase({4: const Left(NetworkFailure(detail: 'ClientException: Failed to fetch, uri=https://nfse.example/v1/nfse/invoices/4/transmit')), 5: const Left(_internal)}, [4, 5]);
      // D-F176: a rede caída não leva o texto da exceção à tela — a página diz "sem conexão"
      expect([net.uncertainRows[0].network, net.uncertainRows[0].supportRef, net.uncertainRows[0].uncertainDetail], [true, '', '']);
      expect(net.uncertainRows[1].uncertainDetail, ' (INTERNAL · ref ab12cd)');
    });

    test('[RESISTIU] PROPRIEDADE — 3.000 lotes aleatórios (semente fixa; 1–12 notas; ok, recusa 422/409, 6 formas de desfecho DESCONHECIDO, 4 formas de erro SISTÊMICO): o relatório bate com um ORÁCULO escrito das decisões (D-F145/D-F155/D-F163/D-F168/D-F171) — cada nota numa única conta, a soma das 4 contas = o pedido, ordem preservada, não tentadas só DEPOIS da parada, nunca 3 incertas seguidas sem parar, `stoppedBy` = a falha da nota que parou, e a frase da parada é a de incerteza SÓ quando ela foi por incertas', () async {
      final rnd = Random(20261013);
      const ok = Right<Failure, ServiceOrderTransmitResult>(_tx);
      final refusals = <Failure>[
        const Failure(message: 'Rejeitada', statusCode: 422, code: 'FISCAL_DPS_REJECTED'),
        const Failure(message: 'Regra', statusCode: 409, code: 'INVOICE_NOT_SERVICE'),
      ];
      final unknowns = <Failure>[
        const NetworkFailure(detail: 'x'), _internal, _proxy503, _bare500,
        const Failure(message: 'busy', statusCode: 409, code: FiscalCodes.resourceBusy),
        invalidResponseFailure('x'),
      ];
      final systemics = <Failure>[
        const Failure(message: 'Sem privilégio', statusCode: 403),
        const UnauthorizedFailure(code: ClientFailureCodes.sessionNotAccepted),
        const Failure(message: 'A1 vencido', statusCode: 422, code: 'FISCAL_CERT_EXPIRED'),
        const Failure(message: 'Sem emissor', statusCode: 409, code: 'FISCAL_ISSUER_MISSING'),
      ];
      for (var run = 0; run < 3000; run++) {
        final n = 1 + rnd.nextInt(12);
        final ids = [for (var i = 0; i < n; i++) 100 + i];
        final by = <int, Either<Failure, ServiceOrderTransmitResult>>{};
        for (final id in ids) {
          final k = rnd.nextInt(10);
          by[id] = k < 3 ? ok : k < 5 ? Left(refusals[rnd.nextInt(2)]) : k < 9 ? Left(unknowns[rnd.nextInt(unknowns.length)]) : Left(systemics[rnd.nextInt(4)]);
        }
        final r = await usecase(by, ids);
        // o ORÁCULO
        final want = <String>[];
        Failure? stop;
        var streak = 0;
        var i = 0;
        for (; i < n; i++) {
          final o = by[ids[i]]!;
          if (o.isRight()) { want.add('T'); streak = 0; continue; }
          final f = o.fold((f) => f, (_) => throw StateError('x'));
          final unknown = unknowns.contains(f);
          want.add(unknown ? 'I' : 'R');
          if (systemics.contains(f)) { stop = f; i++; break; }
          streak = unknown ? streak + 1 : 0;
          if (streak >= 3 && i < n - 1) { stop = f; i++; break; }                 // R8-SOC-02: só PARA quando sobrou nota
        }
        if (stop != null) { for (; i < n; i++) { want.add('N'); } }
        final got = [for (final row in r.rows) row.ok ? 'T' : row.unknown ? 'I' : row.notTried ? 'N' : 'R'];
        expect([run, got], [run, want]);
        expect(r.rows.map((x) => x.orderId).toList(), ids);
        expect(r.transmitted + r.refused + r.uncertain + r.notTried, n);
        expect(r.requested, n);
        expect(r.stoppedBy, stop);
        expect(RegExp('I{4,}').hasMatch(got.join()), isFalse);                 // a 3ª incerta na ÚLTIMA nota termina o lote sem parar
        final stopKey = stop == null ? null : isUnknownAuthorityOutcome(stop) ? 'uncertain' : 'stopped';
        expect(stopKey == 'uncertain', stop != null && !systemics.contains(stop));
      }
    });

    test('[CORRIGIDO — R8-SOC-02] 3 incertas seguidas nas 3 ÚLTIMAS notas: o lote TERMINA sem "parou" (nada ficou para trás); a SISTÊMICA na última segue dizendo "parou: <msg>" (a frase informa a causa)', () async {
      final r = await usecase({1: const Left(_proxy503), 2: const Left(_proxy503), 3: const Left(_proxy503)}, [1, 2, 3]);
      expect([r.uncertain, r.notTried, r.stoppedBy != null], [3, 0, false]);
      final s = await usecase({1: const Right(_tx), 2: const Left(Failure(message: 'Sem privilégio', statusCode: 403))}, [1, 2]);
      expect([s.transmitted, s.refused, s.notTried, s.stoppedBy?.statusCode], [1, 1, 0, 403]);
    });

    test('[RESISTIU] a não tentada nunca carrega a frase da falha que parou o lote para a TELA (a linha é "não tentada — o lote parou antes dela", só com a ordem); a mensagem fica no objeto e não entra em nenhuma das 3 listas de linhas da página além da sua', () async {
      final r = await usecase({1: const Left(Failure(message: 'Sem privilégio', statusCode: 403)), 2: const Right(_tx), 3: const Right(_tx)}, [1, 2, 3]);
      expect(r.notTriedRows.map((x) => x.orderId), [2, 3]);
      final line = 'forms.serviceOrder.fiscalBatchNotTriedRow'.tr(args: ['2']);
      expect(line, 'Ordem 2: não tentada — o lote parou antes dela');
      expect(r.refusedRows.map((x) => x.orderId), [1]);
      expect(r.uncertainRows, isEmpty);
      final src = File(_pageSrc).readAsStringSync();
      expect(src, matches(RegExp(r"for \(final r in report\.notTriedRows\)\r?\n\s+'forms\.serviceOrder\.fiscalBatchNotTriedRow'\.tr\(args: \['\$\{r\.orderId\}'\]\),")));
    });
  });

  // ---------------------------------------------------------------------
  // 2. R7-SOC-03 — o contador de geração do `_reloadList`
  // ---------------------------------------------------------------------
  group('R7-SOC-03 — a recarga superada × recursões, faturamento, detalhe, fechamento', () {
    /// getList que responde na ordem que o TESTE manda: cada chamada fica pendurada num Completer próprio.
    List<Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>> gatedList() {
      final calls = <Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>>[];
      when(() => repo.getList(any(), any(),
              page: any(named: 'page'), pageSize: any(named: 'pageSize'), criteria: any(named: 'criteria')))
          .thenAnswer((_) {
        final c = Completer<Either<Failure, PagedResult<ServiceOrderListItem>>>();
        calls.add(c);
        return c.future;
      });
      return calls;
    }

    test('[RESISTIU] 3 recargas pedidas em sequência e respondidas FORA DE ORDEM (3ª, 1ª, 2ª): só a 3ª emite lista carregada; as superadas não emitem nada; o estado final é a 3ª e não está em loading', () async {
      final calls = gatedList();
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      for (final f in ['a', 'b', 'c']) {
        bloc.add(ServiceOrderListRequested(filter: f));
        await pumpEventQueue();
      }
      expect(calls, hasLength(3));
      calls[2].complete(Right(_page([3])));
      await pumpEventQueue();
      calls[0].complete(Right(_page([1])));
      calls[1].complete(Right(_page([2])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final loaded = states.whereType<ServiceOrderListState>().where((s) => !s.loading).toList();
      expect(loaded.map((s) => s.items.map((i) => i.id).toList()), [[3]]);
      expect((states.last as ServiceOrderListState).loading, isFalse);
    });

    test('[RESISTIU] FATURAR a OS (individual) com uma recarga da aba ABERTAS ainda em voo: a recarga da aba Faturadas (a do faturamento) vence; a foto velha das Abertas, que chega depois, é descartada — a tela não volta a mostrar a OS faturada como aberta', () async {
      final calls = gatedList();
      when(() => repo.invoice(any(), any())).thenAnswer((_) async => const Right(ServiceOrderInvoiceResult(invoiceNumber: '9')));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(status: 'A', filter: ''));
      await pumpEventQueue();
      bloc.add(const ServiceOrderInvoiceRequested(orderId: 7, input: _input));
      await pumpEventQueue();
      expect(calls, hasLength(2));
      calls[1].complete(Right(_page([7], status: 'F')));
      await pumpEventQueue();
      calls[0].complete(Right(_page([7, 8])));                                       // a velha (Abertas) chega depois
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = states.whereType<ServiceOrderListState>().last;
      expect([last.loading, last.status, last.items.map((i) => i.status).toList()], [false, 'F', ['F']]);
    });

    test('[RESISTIU] RECURSÃO pelo critério recusado (Q-BA16 a — descarta + aviso + recarrega) superada por um pedido NOVO no meio: o aviso sai UMA vez, a recarga da recursão (superada) não emite, o estado final é o do pedido novo — sem o critério recusado e sem loading', () async {
      final calls = gatedList();
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(criteria: SearchCriteriaValues({'customer': 'x'})));
      await pumpEventQueue();
      calls[0].complete(const Left(Failure(message: 'critério', statusCode: 400, code: 'SEARCH_CRITERION_INVALID',
          fields: [FailureField(field: 'customer', message: 'inválido')])));
      await pumpEventQueue();
      expect(calls, hasLength(2));                                                    // a recursão pediu de novo
      bloc.add(const ServiceOrderListRequested(filter: 'novo'));
      await pumpEventQueue();
      expect(calls, hasLength(3));
      calls[2].complete(Right(_page([30])));
      await pumpEventQueue();
      calls[1].complete(Right(_page([20])));                                         // a da recursão chega depois
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.whereType<ServiceOrderActionFailure>().map((s) => s.failure.message).toList(), ['search.criterionRemoved']);
      final last = states.whereType<ServiceOrderListState>().last;
      expect([last.loading, last.items.single.id, last.criteria.isEmpty, last.filter], [false, 30, true, 'novo']);
    });

    test('[RESISTIU] RECURSÃO da página que esvaziou (recua à última) superada pela troca para a página 1: vale a página 1; a recarga da recursão (página 2) não emite', () async {
      final calls = gatedList();
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(page: 3));
      await pumpEventQueue();
      calls[0].complete(Right(_page([], page: 3, total: 15)));                       // página 3 vazia, 2 páginas existem
      await pumpEventQueue();
      expect(calls, hasLength(2));
      bloc.add(const ServiceOrderListRequested(page: 1));
      await pumpEventQueue();
      calls[2].complete(Right(_page([1, 2], page: 1, total: 15)));
      await pumpEventQueue();
      calls[1].complete(Right(_page([11], page: 2, total: 15)));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      final last = states.whereType<ServiceOrderListState>().last;
      expect([last.loading, last.page, last.items.map((i) => i.id).toList()], [false, 1, [1, 2]]);
    });

    test('[DECIDIDO D-F174 (= Q-F182 (b)) — era o FATO pré-existente] entrar no detalhe INVALIDA a recarga em voo: o contador antes só protegia LISTA × LISTA; o FAB "Abrir OS" (não é travado pelo loading) disparado com uma recarga da lista em voo abre o detalhe da OS nova — e a lista VELHA, que chega depois, SUBSTITUI o detalhe (o operador volta à lista sem ter pedido; a OS foi criada). O mesmo acontece com a recarga FINAL de um lote: abrir uma OS pelo FAB durante o lote e o fim do lote devolve a tela à lista', () async {
      final calls = gatedList();
      when(() => repo.open(any())).thenAnswer((_) async => const Right(77));
      when(() => repo.getById(77)).thenAnswer((_) async => const Right(ServiceOrderFull(id: 77, customerId: 5)));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ServiceOrderListRequested(filter: ''));
      await pumpEventQueue();
      bloc.add(const ServiceOrderOpenRequested(5));
      await pumpEventQueue();
      expect(states.last, isA<ServiceOrderDetailState>());
      calls[0].complete(Right(_page([1])));
      await pumpEventQueue(times: 20);
      await sub.cancel();
      await bloc.close();
      expect(states.last, isA<ServiceOrderDetailState>(), reason: 'a lista velha que chega depois não tira o operador da OS que ele abriu');
    });

    test('[RESISTIU] o bloc FECHADO com uma recarga em voo: a resposta que chega depois não emite nem lança (o `isClosed` do bloc 8 torna o emit no-op); e uma recarga superada pelo fechamento + reabertura de um bloc NOVO não interfere no novo (o contador é por instância)', () async {
      final calls = gatedList();
      final a = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final seenA = <ServiceOrderState>[];
      final subA = a.stream.listen(seenA.add);
      a.add(const ServiceOrderListRequested(filter: ''));
      await pumpEventQueue();
      await subA.cancel();
      await a.close();
      final b = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final seenB = <ServiceOrderState>[];
      final subB = b.stream.listen(seenB.add);
      b.add(const ServiceOrderListRequested(filter: ''));
      await pumpEventQueue();
      calls[1].complete(Right(_page([2])));
      await pumpEventQueue();
      calls[0].complete(Right(_page([1])));
      await pumpEventQueue(times: 20);
      await subB.cancel();
      await b.close();
      expect(seenA.whereType<ServiceOrderListState>().where((s) => !s.loading), isEmpty);
      final last = seenB.whereType<ServiceOrderListState>().last;
      expect([last.loading, last.items.single.id], [false, 2]);
    });
  });
}
