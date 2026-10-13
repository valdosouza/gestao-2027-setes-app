// "Transmitir notas sem NFS-e" (F2b — D-F145 = Q-F153 (a), Valdo 2026-10-13):
// o lote roda NO APP contra a nfse-api, que não tem lote no servidor. O que
// este teste fixa é (1) o passo 1 FOTOGRAFA a lista — todas as páginas, sem
// repetir nota que "andou" de página, até o teto, e página que falha no meio
// = falha inteira; (2) UMA nota por vez, na ordem, e erro DA NOTA vira linha
// do relatório sem parar o lote; (3) erro SISTÊMICO (sessão, privilégio,
// certificado, virada pendente, N desfechos desconhecidos seguidos) PARA o
// lote e o resto entra como "não tentada"; (4) UM lote por vez no bloc — o 2º
// disparo enquanto o 1º roda é IGNORADO (H1 do gate socrático da Rodada 5).

import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_pending.dart';
import 'package:setes_web/app/modules/service_orders/domain/usecase/service_order_fiscal_transmit_batch.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';

import 'support/service_order_bloc_factory.dart';

const _authorized = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');

List<int> _ids(int n) => List.generate(n, (i) => i + 1);

PagedResult<ServiceOrderFiscalPending> _page(List<int> ids, {required int page, required int total, int pageSize = 2}) =>
    PagedResult(
      items: [for (final id in ids) ServiceOrderFiscalPending(invoiceId: id, number: '$id')],
      page: page,
      pageSize: pageSize,
      total: total,
    );

/// Dispara [event] e devolve os estados emitidos até a lista recarregar
/// (o bloc SEMPRE termina com a lista carregada, com ou sem relatório).
Future<List<ServiceOrderState>> _run(ServiceOrderBloc bloc, ServiceOrderEvent event) async {
  final states = <ServiceOrderState>[];
  final sub = bloc.stream.listen(states.add);
  final done = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);
  bloc.add(event);
  await done;
  await sub.cancel();
  await bloc.close();
  return states;
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
  });

  setUp(() {
    repo = ServiceOrderRepoMock();
    nfse = NfseRepoMock();
    when(() => repo.getList(any(), any(),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            criteria: any(named: 'criteria')))
        .thenAnswer((_) async => const Right(PagedResult.empty()));
  });

  void transmiteTudo() => when(() => nfse.transmit(any())).thenAnswer((_) async => const Right(_authorized));

  List<int> transmitidas() => verify(() => nfse.transmit(captureAny())).captured.cast<int>();

  group('passo 1 — a lista fotografada (todas as páginas, sem repetir, até o teto)', () {
    test('lê as páginas até a última e devolve a união sem repetição', () async {
      when(() => nfse.pending(page: 1, pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => Right(_page([10, 11], page: 1, total: 5)));
      when(() => nfse.pending(page: 2, pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => Right(_page([11, 12], page: 2, total: 5))); // a 11 "andou"
      when(() => nfse.pending(page: 3, pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => Right(_page([13], page: 3, total: 5)));

      final r = await ServiceOrderFiscalPendingList(repository: nfse, pageSize: 2)();

      expect(r.getOrElse(() => []).map((p) => p.invoiceId), [10, 11, 12, 13]);
      verifyNever(() => nfse.pending(page: 4, pageSize: any(named: 'pageSize')));
    });

    test('para no teto do lote (fiscalBatchMaxNotes) — o resto fica para o próximo', () async {
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer((inv) async {
        final page = inv.namedArguments[#page] as int;
        final base = (page - 1) * 100;
        return Right(_page(List.generate(100, (i) => base + i + 1), page: page, total: 10000, pageSize: 100));
      });

      final r = await ServiceOrderFiscalPendingList(repository: nfse)();

      expect(r.getOrElse(() => []).length, fiscalBatchMaxNotes);
    });

    test('página que falha no meio = falha inteira (lista pela metade enganaria a confirmação)', () async {
      when(() => nfse.pending(page: 1, pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => Right(_page([10, 11], page: 1, total: 4)));
      when(() => nfse.pending(page: 2, pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      final r = await ServiceOrderFiscalPendingList(repository: nfse, pageSize: 2)();

      expect(r.isLeft(), isTrue);
    });

    test('bloc: devolve a lista no one-shot para a página confirmar e recarrega a lista', () async {
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => Right(_page([10, 11], page: 1, total: 2)));

      final states = await _run(buildServiceOrderBloc(repo: repo, nfse: nfse), const ServiceOrderFiscalPendingRequested());

      expect(states.whereType<ServiceOrderFiscalPendingLoaded>().single.pending.map((p) => p.orderId), [10, 11]);
      verifyNever(() => nfse.transmit(any()));
    });

    test('bloc: falha do GET pendentes sobe como Failure (ponte trata)', () async {
      when(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer(
          (_) async => const Left(Failure(message: 'Sem privilégio', statusCode: 403)));

      final states = await _run(buildServiceOrderBloc(repo: repo, nfse: nfse), const ServiceOrderFiscalPendingRequested());

      expect(states.whereType<ServiceOrderFiscalPendingLoaded>(), isEmpty);
      expect(states.whereType<ServiceOrderActionFailure>().single.failure.statusCode, 403);
    });
  });

  group('R8-SOC-02 (gate socrático da Rodada 8): "o lote parou" só quando sobrou nota', () {
    test('3 incertas seguidas nas 3 ÚLTIMAS notas: nada deixou de ser tentado — sem parada, sem não tentadas', () async {
      when(() => nfse.transmit(any())).thenAnswer((_) async => const Left(Failure(message: 'gw', statusCode: 504)));
      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)(_ids(3));
      expect([r.uncertain, r.notTried, r.stoppedBy], [3, 0, null]);
    });
  });

  group('passo 2 — uma nota por vez, erro da nota não para o lote', () {
    test('transmite na ordem, ids repetidos contam uma vez, relatório agregado', () async {
      transmiteTudo();

      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)([3, 1, 2, 1, 3]);

      expect(transmitidas(), [3, 1, 2]);
      expect(r.requested, 3);
      expect(r.transmitted, 3);
      expect(r.refused, 0);
      expect(r.stoppedBy, isNull);
    });

    test('recusa do fisco (422) e regra (409) viram linha e o lote SEGUE', () async {
      when(() => nfse.transmit(any())).thenAnswer((inv) async => switch (inv.positionalArguments[0] as int) {
            2 => const Left(Failure(message: 'E0116 IM obrigatória', statusCode: 422, code: FiscalCodes.dpsRejected)),
            3 => const Left(Failure(message: 'Nota em uso', statusCode: 409, code: FiscalCodes.resourceBusy)),
            _ => const Right(_authorized),
          });

      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)(_ids(4));

      expect(transmitidas(), [1, 2, 3, 4]);
      expect(r.transmitted, 2);
      // D-F163/D-F168: o 409 RESOURCE_BUSY num ato é desfecho DESCONHECIDO — "incerta", não "recusada"
      expect([r.refused, r.uncertain], [1, 1]);
      expect(r.uncertainRows.single.orderId, 3);
      expect(r.uncertainRows.single.code, FiscalCodes.resourceBusy);
      expect(r.rows[1].code, FiscalCodes.dpsRejected);
      expect(r.rows[1].message, 'E0116 IM obrigatória');
      expect(r.stoppedBy, isNull);
    });

    test('desfecho desconhecido isolado não para o lote (o contador zera no sucesso)', () async {
      when(() => nfse.transmit(any())).thenAnswer((inv) async => (inv.positionalArguments[0] as int).isEven
          ? const Left(Failure(message: 'ambíguo', statusCode: 502, code: FiscalCodes.authorityUnknown))
          : const Right(_authorized));

      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)(_ids(6));

      expect(transmitidas().length, 6);
      expect(r.stoppedBy, isNull);
    });
  });

  group('passo 2 — erro SISTÊMICO para o lote (o resto = não tentada)', () {
    final sistemicos = <String, Failure>{
      'sessão (401)': const UnauthorizedFailure(),
      'privilégio/licença (403)': const Failure(message: 'Sem privilégio', statusCode: 403, code: 'PRIVILEGE_REQUIRED'),
      'certificado': const Failure(message: 'A1 vencido', statusCode: 409, code: 'FISCAL_CERT_EXPIRED'),
      'habilitação ausente': const Failure(message: 'Sem habilitação', statusCode: 409, code: 'FISCAL_ISSUER_MISSING'),
      'virada pendente (D-F143)': const Failure(message: 'Emissão ainda pelo ERP', statusCode: 409, code: FiscalCodes.cutoverPending),
      'cofre sem chave': const Failure(message: 'Cofre', statusCode: 503, code: 'FISCAL_MASTER_KEY_UNAVAILABLE'),
    };
    for (final e in sistemicos.entries) {
      test('${e.key} na 2ª nota → para; 3ª e 4ª abortadas com a mensagem do motivo', () async {
        when(() => nfse.transmit(any()))
            .thenAnswer((inv) async => inv.positionalArguments[0] == 2 ? Left(e.value) : const Right(_authorized));

        final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)(_ids(4));

        expect(transmitidas(), [1, 2]);
        expect(r.requested, 4);
        expect(r.transmitted, 1);
        expect(r.stoppedBy, e.value);
        expect(r.rows[2].code, FiscalTransmitBatchRow.abortedCode);
        expect(r.rows[3].orderId, 4);
        expect(r.rows[3].message, e.value.message);
      });
    }

    test('3 desfechos desconhecidos SEGUIDOS (fisco fora) → para; não insiste nota a nota', () async {
      when(() => nfse.transmit(any())).thenAnswer((inv) async => (inv.positionalArguments[0] as int) == 1
          ? const Right(_authorized)
          : const Left(NetworkFailure()));

      final r = await ServiceOrderFiscalTransmitBatch(repository: nfse)(_ids(10));

      expect(transmitidas(), [1, 2, 3, 4]);
      expect(r.stoppedBy, isA<NetworkFailure>());
      expect(r.requested, 10);
      expect(r.rows.skip(4).every((row) => row.code == FiscalTransmitBatchRow.abortedCode), isTrue);
    });

    test('shouldStop (tela fechou) para antes da próxima nota', () async {
      var stop = false;
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        stop = true;
        return const Right(_authorized);
      });

      await ServiceOrderFiscalTransmitBatch(repository: nfse)(_ids(5), shouldStop: () => stop);

      expect(transmitidas(), [1]);
    });
  });

  group('bloc — um lote por vez (H1 do gate socrático da Rodada 5)', () {
    test('relatório chega no one-shot e a lista recarrega', () async {
      transmiteTudo();

      final states = await _run(
          buildServiceOrderBloc(repo: repo, nfse: nfse), ServiceOrderFiscalTransmitBatchRequested(_ids(3)));

      final done = states.whereType<ServiceOrderFiscalBatchDone>().single;
      expect(done.report.transmitted, 3);
      expect(states.whereType<ServiceOrderActionFailure>(), isEmpty);
    });

    test('2º disparo enquanto o 1º ainda roda é IGNORADO — nenhuma chamada extra, um relatório só', () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((_) async {
        await gate.future; // segura a 1ª nota "no fisco"
        return const Right(_authorized);
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final done = bloc.stream.firstWhere((s) => s is ServiceOrderListState && !s.loading);

      bloc.add(ServiceOrderFiscalTransmitBatchRequested(_ids(3)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ServiceOrderFiscalTransmitBatchRequested(_ids(3)));
      await Future<void>.delayed(Duration.zero);
      // nem o passo 1 entra no meio de um lote em andamento
      bloc.add(const ServiceOrderFiscalPendingRequested());
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await done;
      await sub.cancel();
      await bloc.close();

      expect(transmitidas(), [1, 2, 3]);
      expect(states.whereType<ServiceOrderFiscalBatchDone>().length, 1);
      verifyNever(() => nfse.pending(page: any(named: 'page'), pageSize: any(named: 'pageSize')));
    });
  });
}
