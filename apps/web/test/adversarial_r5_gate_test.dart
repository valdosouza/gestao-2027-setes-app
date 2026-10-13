// GATE ADVERSARIAL do DELTA da Rodada 5 da F2a/F2b (setes-app) — alvo: commit
// 5c80e20 (delta sobre bbeb1d6): D-F155 (o 500 da nfse-api num ATO = desfecho
// desconhecido), D-F156 (`stopBatches()` + o `onDispose` que FECHA o bloc) e
// as correções dos re-gates (build-web.ps1, urlProblems, sessão fresca…).
//
// Convenção do gate (a mesma dos gates anteriores):
//   - `[ACHADO R5-ADV-NN SEV]` = o teste descreve o comportamento CERTO e hoje
//     FALHA — fica com `skip:` para a suíte seguir verde. Para ver a falha:
//       flutter test --run-skipped test/adversarial_r5_gate_test.dart
//   - `[Q-F168-ADV-NN — decisão]` = depende de decisão do Valdo (também pulado).
//   - `[RESISTIU]` = o ataque foi barrado (roda sempre).
//   - `[FATO …]` = comportamento atual registrado (roda sempre).
// Nada aqui fala com servidor: repositórios mocktail. Os testes do
// `build-web.ps1` só avaliam a função de validação no Windows PowerShell 5.1.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/modules/service_orders/presentation/bloc/service_order_bloc.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

import 'support/service_order_bloc_factory.dart';

const _orderId = 7374;
const _reason = 'Serviço não prestado no mês';
const _order = ServiceOrderFull(id: _orderId, customerId: 1, status: 'F');
const _authorizedVoice = ServiceOrderFiscalView(state: NfseState.authorized, currentAttempt: 1);
const _authorizedTx = ServiceOrderTransmitResult(invoiceId: 0, attempt: 1, accessKey: 'K');
const _local = ServiceOrderInvoiceCancelResult(orderId: _orderId, invoiceNumber: '704', event: 3);
const _internal = Failure(message: 'Erro interno', statusCode: 500, code: 'INTERNAL', supportRef: 'AB12CD34');
const _bare500 = Failure(message: 'core.errors.generic', statusCode: 500);
// o 409 que a nfse-api devolve quando a gravação DEPOIS do fisco esbarra numa trava (lock wait → contentionToHttpError)
const _busy = Failure(message: 'Recurso ocupado — tente de novo', statusCode: 409, code: 'RESOURCE_BUSY');

// R5-ADV-08 CORRIGIDO na sessão (a mesma regra de host no app e no script) — os 3 testes rodam sempre (no Windows).

ServiceOrderCancelPlan _onlyAuthority() => const ServiceOrderCancelPlan(orderId: _orderId, fiscalRecord: true, blocks: [
      CancelPlanBlock(field: 'fiscal', message: 'NFS-e autorizada', barrier: FiscalBarrier(kind: FiscalBarrierKind.authorized)),
    ]);

/// Roda um script no Windows PowerShell 5.1 por `-EncodedCommand` (UTF-16LE).
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

class _ProbeEvent {}

/// Bloc mínimo para medir o `close()` do bloc 8.1.4 com um handler em voo.
class _ProbeBloc extends Bloc<_ProbeEvent, int> {
  _ProbeBloc(this.gate) : super(0) {
    on<_ProbeEvent>((_, emit) async {
      started = true;
      await gate.future;
      continued = true;
      emit(1);
    });
  }
  final Completer<void> gate;
  bool started = false;
  bool continued = false;
}

void main() {
  late ServiceOrderRepoMock repo;
  late NfseRepoMock nfse;
  late InvoiceRepoMock invoice;

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(SearchCriteriaValues.empty);
    registerFallbackValue(const ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0));
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

  /// Dispara [event] no detalhe aberto e devolve os estados até o detalhe voltar (sem `saving`).
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
  // 1. D-F155 — o 500 num ATO é desfecho desconhecido; na LEITURA, falha comum
  // ---------------------------------------------------------------------
  group('D-F155 — 500 da nfse-api', () {
    test('[RESISTIU] Transmitir com 500 INTERNAL e com 500 SEM código → "resultado incerto — consulte" (nunca a falha seca) e o detalhe RELÊ',
        () async {
      for (final f in [_internal, _bare500]) {
        when(() => nfse.transmit(_orderId)).thenAnswer((_) async => Left(f));
        final states = await runDetail(await opened(), const ServiceOrderTransmitRequested(_orderId));
        expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown', reason: '${f.code}');
        expect(states.whereType<ServiceOrderActionFailure>(), isEmpty, reason: '${f.code}');
      }
    });

    test('[RESISTIU] Reconferir com 500 → desconhecido; Cancelar no fisco com 500 → desconhecido e o ERP NUNCA é chamado (a saga para no estágio do fisco)',
        () async {
      when(() => nfse.reconfirm(_orderId)).thenAnswer((_) async => const Left(_internal));
      final r = await runDetail(await opened(), const ServiceOrderFiscalReconfirmRequested(_orderId));
      expect(r.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown');
      when(() => nfse.cancel(_orderId, _reason)).thenAnswer((_) async => const Left(_internal));
      when(() => invoice.cancel(any(), any())).thenAnswer((_) async => const Right(_local));
      final c = await runDetail(await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      expect(c.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown');
      verifyNever(() => invoice.cancel(any(), any()));
    });

    test('[RESISTIU] 500 com OUTRO código da casa (erro TIPADO, não o genérico) segue falha comum — a D-F155 é só INTERNAL/sem código', () {
      expect(isUnknownAuthorityOutcome(const Failure(message: 'x', statusCode: 500, code: 'FISCAL_STORAGE_FAILED')), isFalse);
      expect([isUnknownAuthorityOutcome(_internal), isUnknownAuthorityOutcome(_bare500)], [true, true]);
    });

    test('[RESISTIU] LEITURA com 500 (abrir a OS faturada; a releitura do plano antes do fisco): "indisponível"/falha comum — nunca o aviso de desfecho desconhecido',
        () async {
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Left(_internal));
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      final shown = bloc.stream.firstWhere((s) => s is ServiceOrderDetailState && s.fiscalFailure != null);
      bloc.add(const ServiceOrderViewRequested(_orderId));
      final detail = await shown as ServiceOrderDetailState;
      await sub.cancel();
      await bloc.close();
      expect(detail.fiscalFailure, _internal);
      expect(states.whereType<ServiceOrderFiscalNotice>(), isEmpty);
      // a releitura do plano (D-F149) que dá 500: nada foi ao fisco — falha comum, nunca "consulte"
      when(() => nfse.getView(_orderId)).thenAnswer((_) async => const Right(_authorizedVoice));
      when(() => invoice.cancelPlan(_orderId)).thenAnswer((_) async => const Left(_internal));
      final c = await runDetail(await opened(), const ServiceOrderCancelConfirmed(orderId: _orderId, reason: _reason, atAuthority: true));
      verifyNever(() => nfse.cancel(any(), any()));
      expect(c.whereType<ServiceOrderFiscalNotice>(), isEmpty);
      expect(c.whereType<ServiceOrderActionFailure>().single.failure, _internal);
    });

    test('[RESISTIU] lote: 3 × 500 SEGUIDOS param o lote (o fisco/serviço fora não se insiste); 500, ok, 500, 500 segue (a sequência zera)',
        () async {
      Future<FiscalTransmitBatchReport> runWith(Map<int, Either<Failure, ServiceOrderTransmitResult>> by, List<int> ids) async {
        when(() => nfse.transmit(any())).thenAnswer((inv) async => by[inv.positionalArguments[0] as int]!);
        final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
        final done = bloc.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
        bloc.add(ServiceOrderFiscalTransmitBatchRequested(ids));
        final r = (await done as ServiceOrderFiscalBatchDone).report;
        await bloc.close();
        return r;
      }
      final stop = await runWith({1: const Left(_internal), 2: const Left(_bare500), 3: const Left(_internal), 4: const Right(_authorizedTx)}, [1, 2, 3, 4]);
      expect([stop.stoppedBy, stop.transmitted, stop.rows.length], [_internal, 0, 4]);
      final goOn = await runWith({1: const Left(_internal), 2: const Right(_authorizedTx), 3: const Left(_internal), 4: const Left(_internal)}, [1, 2, 3, 4]);
      expect([goOn.stoppedBy, goOn.transmitted, goOn.refused, goOn.uncertain], [null, 1, 0, 3]);   // D-F168: desconhecido = incerta
    });

    test('[DECIDIDO D-F163 (= Q-F171 (a))] 409 RESOURCE_BUSY num ATO: a nfse-api devolve-o quando a gravação da voz DEPOIS do fisco esbarra numa trava (lock wait → `contentionToHttpError`, `transmission.ts` (g)/(5)) — a NFS-e pode ter sido autorizada/cancelada. Pela razão da D-F155 seria desconhecido; hoje é "tente de novo"',
        () async {
      when(() => nfse.transmit(_orderId)).thenAnswer((_) async => const Left(_busy));
      final states = await runDetail(await opened(), const ServiceOrderTransmitRequested(_orderId));
      expect(states.whereType<ServiceOrderFiscalNotice>().single.messageKey, 'forms.serviceOrder.fiscalOutcomeUnknown');
    });

    test('[DECIDIDO D-F163] RESOURCE_BUSY num ato é desfecho desconhecido; nas LEITURAS segue falha comum (o classificador é só dos atos)', () {
      expect(isUnknownAuthorityOutcome(_busy), isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // 2. D-F156 — sair da tela PARA os lotes; o close do bloc 8
  // ---------------------------------------------------------------------
  group('D-F156 — stopBatches() + onDispose (close)', () {
    test('[FATO — R5-ADV-07 LOW (conhecimento negativo errado)] bloc 8.1.4: `close()` CANCELA o emissor e devolve LOGO — `isClosed` vira TRUE com o handler AINDA em voo (ele segue rodando depois); a D-F156 e o comentário do bloc dizem o contrário ("o `isClosed` só vira true quando ele termina — o close os espera")',
        () async {
      final gate = Completer<void>();
      final bloc = _ProbeBloc(gate)..add(_ProbeEvent());
      await pumpEventQueue();
      expect(bloc.started, isTrue);
      await bloc.close().timeout(const Duration(seconds: 2)); // NÃO espera o handler
      expect([bloc.isClosed, bloc.continued], [true, false]);
      gate.complete();
      await pumpEventQueue();
      expect(bloc.continued, isTrue, reason: 'o handler continuou depois do close (o emit virou no-op)');
      expect(() => bloc.add(_ProbeEvent()), throwsStateError, reason: 'evento depois do close = StateError');
    });

    test('[RESISTIU] o lote fiscal em voo + `onDispose` (stopBatches + close): a nota em voo termina, as seguintes NÃO vão ao fisco, sem relatório',
        () async {
      final gate = Completer<void>();
      when(() => nfse.transmit(any())).thenAnswer((inv) async {
        if (inv.positionalArguments[0] == 1) await gate.future;
        return const Right(_authorizedTx);
      });
      final old = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = old.stream.listen(states.add);
      old.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2, 3]));
      await pumpEventQueue();
      old.stopBatches(); // o onDispose do módulo…
      unawaited(old.close()); // …e o close sem await (como no módulo)
      gate.complete();
      await pumpEventQueue();
      await sub.cancel();
      verify(() => nfse.transmit(1)).called(1);
      verifyNever(() => nfse.transmit(2));
      expect(states.whereType<ServiceOrderFiscalBatchDone>(), isEmpty);
    });

    test('[FATO — analisado] voltar à tela = bloc NOVO (o Modular recria o singleton do módulo): o lote novo NÃO espera a nota em voo do bloc antigo — as duas instâncias mandam a MESMA nota ao mesmo tempo; quem serializa é a trava da nota na nfse-api (2ª = 409 em andamento → linha do relatório)',
        () async {
      final gate = Completer<void>();
      var inFlight = 0;
      var maxInFlight = 0;
      when(() => nfse.transmit(any())).thenAnswer((inv) async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        if (inv.positionalArguments[0] == 1 && !gate.isCompleted) await gate.future;
        inFlight--;
        return const Right(_authorizedTx);
      });
      final old = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      old.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      await pumpEventQueue();
      old.stopBatches();
      unawaited(old.close());
      final fresh = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final done = fresh.stream.firstWhere((s) => s is ServiceOrderFiscalBatchDone);
      fresh.add(const ServiceOrderFiscalTransmitBatchRequested([1, 2]));
      await pumpEventQueue();
      expect(maxInFlight, 2, reason: 'a nota 1 em voo nas DUAS instâncias');
      gate.complete();
      final report = (await done as ServiceOrderFiscalBatchDone).report;
      await fresh.close();
      expect(report.transmitted, 2);
      verify(() => nfse.transmit(1)).called(2);
      verify(() => nfse.transmit(2)).called(1); // só o bloc novo
    });

    test('[RESISTIU] faturamento em lote: `stopBatches` no meio + lote NOVO no MESMO bloc logo depois → o novo é IGNORADO enquanto o antigo termina o bloco em voo (um lote por vez); o antigo não manda o 2º bloco e não emite relatório',
        () async {
      final gate = Completer<void>();
      final calls = <int>[];
      when(() => repo.batchInvoice(any(), any())).thenAnswer((inv) async {
        final ids = inv.positionalArguments[0] as List<int>;
        calls.add(ids.length);
        if (calls.length == 1) await gate.future;
        return Right(BatchInvoiceReport.fromEntries([
          for (final id in ids) BatchInvoiceEntry(orderId: id, ok: true, invoiceNumber: '$id', chargedParcels: 1, chargeableParcels: 1),
        ]));
      });
      final bloc = buildServiceOrderBloc(repo: repo, nfse: nfse, invoice: invoice);
      final states = <ServiceOrderState>[];
      final sub = bloc.stream.listen(states.add);
      const input = ServiceOrderInvoiceInput(dtExpiration: '', paymentTypeId: 0);
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: List.generate(120, (i) => i + 1), input: input));
      await pumpEventQueue();
      bloc.stopBatches();
      bloc.add(ServiceOrderBatchInvoiceRequested(orderIds: List.generate(10, (i) => 1000 + i), input: input));
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();
      await sub.cancel();
      await bloc.close();
      expect(calls, [50], reason: 'só o bloco que estava em voo — o lote novo foi ignorado (_batchRunning) e o antigo parou');
      expect(states.whereType<ServiceOrderBatchInvoiceDone>(), isEmpty);
    });

    test('[CORRIGIDO R5-ADV-07] com o bloc agora FECHADO no onDispose, `add` depois da tela sair lança StateError — os caminhos `await <diálogo>` → `_bloc.add(...)` (abrir OS, rotina mensal, pesquisa avançada) conferem `mounted` antes',
        () {
      final src = File('lib/app/modules/service_orders/presentation/page/service_order_page.dart').readAsStringSync();
      String body(String name) {
        final i = src.indexOf('Future<void> $name(');
        return src.substring(i, src.indexOf('\n  }', i));
      }
      // D-F184 (= Q-F192 (a)): a DECISÃO vai ao bloc se ELE está vivo (`_dispatch` confere o `isClosed`) — não pelo `mounted` da página
      // (os diálogos sobrevivem à página recriada ao cruzar 1100 px); a pesquisa avançada aplica no estado da PÁGINA e segue pelo `mounted`
      final dispatch = src.substring(src.indexOf('void _dispatch('), src.indexOf('\n  }', src.indexOf('void _dispatch(')));
      expect(dispatch, contains('if (!_bloc.isClosed) _bloc.add(event);'));
      for (final f in ['_openNewOrder', '_openMonthlyRun', '_askTransmitPending', '_askKeepInvoice']) {
        final b = body(f);
        expect([f, b.contains('await '), b.contains('_dispatch('), b.contains('_bloc.add('), b.contains('!mounted')], [f, true, true, false, false]);
      }
      final search = body('_openAdvancedSearch');
      expect([search.contains('await '), search.contains('if (!mounted) return;')], [true, true]);
    });
  });

  // ---------------------------------------------------------------------
  // 3. build-web.ps1 × AppConfig.urlProblems × o navegador
  // ---------------------------------------------------------------------
  group('build-web.ps1 — "a MESMA regra do app" e o que o NAVEGADOR recusa', () {
    Future<Map<String, bool>> scriptVerdicts(List<String> cases) async {
      final src = File('build-web.ps1').readAsStringSync();
      final fn = RegExp(r'^function Test-ApiUrl[\s\S]*?^\}', multiLine: true).firstMatch(src)!.group(0)!;
      final out = await _ps('$fn\n'
          "foreach (\$v in @(${cases.map((c) => "'$c'").join(', ')})) "
          r"{ try { Test-ApiUrl 'NFSE_API_URL' $v; $v + '|ACEITA' } catch { $v + '|RECUSA' } }");
      return {for (final l in LineSplitter.split(out)) l.split('|').first.trim(): l.split('|').last.trim() == 'ACEITA'};
    }

    test('[CORRIGIDO R5-ADV-08 LOW] host que o NAVEGADOR recusa (termina em número e não é IPv4 válido — WHATWG): o script ACEITA e o app ACEITA → build publicado em que TODA chamada é NetworkFailure (cada ato = "desfecho desconhecido") — a classe que o RG-08 diz ter fechado',
        () async {
      const cases = ['https://a.1', 'https://999.999.999.999', 'https://1.2.3.4.5'];
      final script = await scriptVerdicts(cases);
      for (final c in cases) {
        expect([c, script[c], AppConfig.urlProblems('NFSE_API_URL', c).isEmpty], [c, false, false]);
      }
    }, skip: Platform.isWindows ? false : 'só no Windows');

    test('[CORRIGIDO R5-ADV-08 LOW] o script ACEITA e o app RECUSA (a promessa do RG-02 — "a MESMA regra do app" — cai): ponto final no host, `localhost.` (loopback que o script não vê), sublinhado → o build publicado abre a tela de erro de configuração',
        () async {
      const cases = ['https://api.setes.com.br.', 'https://localhost.', 'https://nfse_api.setes.com.br'];
      final script = await scriptVerdicts(cases);
      for (final c in cases) {
        expect([c, script[c]], [c, AppConfig.urlProblems('NFSE_API_URL', c).isEmpty]);
      }
    }, skip: Platform.isWindows ? false : 'só no Windows');

    test('[CORRIGIDO R5-ADV-08 LOW] endereço "não especificado" (0.0.0.0, [::]) passa no guarda de PUBLICAÇÃO sem loopback (o .NET não o chama de loopback; o navegador o trata como a máquina do usuário ou recusa)',
        () async {
      final script = await scriptVerdicts(['https://0.0.0.0', 'https://[::]']);
      expect(script, {'https://0.0.0.0': false, 'https://[::]': false});
    }, skip: Platform.isWindows ? false : 'só no Windows');

    test('[RESISTIU] IPv6/porta padrão/http: loopback IPv6 e IPv4 disfarçado (::1, ::ffff:127.0.0.1, 0x7f.1, 2130706433, 127.000.000.001) RECUSADOS; https com :443 e IPv6 público ACEITOS nos dois; http sempre RECUSADO na publicação',
        () async {
      const refused = ['https://[::1]', 'https://[::ffff:127.0.0.1]', 'https://0x7f.1', 'https://2130706433', 'https://127.000.000.001',
        'http://api.setes.com.br', 'http://localhost:3002'];
      const accepted = ['https://api.setes.com.br:443', 'https://[2001:db8::1]', 'https://API.SETES.COM.BR'];
      final v = await scriptVerdicts([...refused, ...accepted]);
      for (final c in refused) {
        expect([c, v[c]], [c, false]);
      }
      for (final c in accepted) {
        expect([c, v[c], AppConfig.urlProblems('NFSE_API_URL', c)], [c, true, isEmpty]);
      }
    }, skip: Platform.isWindows ? false : 'só no Windows');
  });
}
