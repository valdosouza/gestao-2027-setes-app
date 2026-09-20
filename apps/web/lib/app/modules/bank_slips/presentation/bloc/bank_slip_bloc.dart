import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/bank_slip_entity.dart';
import '../../domain/usecase/bank_slip_bank_sync.dart';
import '../../domain/usecase/bank_slip_cancel.dart';
import '../../domain/usecase/bank_slip_get.dart';
import '../../domain/usecase/bank_slip_pdf.dart';
import '../../domain/usecase/bank_slip_refresh.dart';
import '../../domain/usecase/bank_slip_register.dart';
import '../../domain/usecase/bank_slip_getlist.dart';
import '../../domain/usecase/bank_slip_issue.dart';
import '../../domain/usecase/bank_slip_reverse.dart';
import '../../domain/usecase/bank_slip_settle.dart';

part 'bank_slip_event.dart';
part 'bank_slip_state.dart';

/// Orquestra a tela de Boletos (TELA DE PROCESSO — prompt_boleto_emitido.md
/// D1–D11): lista por estado DERIVADO (abas Abertos × Liquidados ×
/// Cancelados, `?status=`), detalhe dirigido pelo estado e ações
/// transacionais — emitir (E), liquidar (L), cancelar (C), estornar (X).
/// Toda ação chama a API e RECARREGA o detalhe (o estado e a linha do
/// tempo são do servidor). Falhas carregam o [Failure] INTEIRO no one-shot
/// (Framework de Mensagens): a página entrega à PONTE, que deriva o canal —
/// os 409 de negócio viram dialog de validação com a mensagem da API.
class BankSlipBloc extends Bloc<BankSlipEvent, BankSlipState> {
  BankSlipBloc({
    required this.getlist,
    required this.get,
    required this.issue,
    required this.settle,
    required this.cancel,
    required this.reverse,
    required this.register,
    required this.refresh,
    required this.pdf,
    required this.bankSync,
  }) : super(const BankSlipListState(loading: true)) {
    on<BankSlipListRequested>(_onListRequested);
    on<BankSlipViewRequested>(_onViewRequested);
    on<BankSlipBackToListPressed>(_onBackToList);
    on<BankSlipIssueRequested>(_onIssueRequested);
    on<BankSlipSettleRequested>(_onSettleRequested);
    on<BankSlipCancelRequested>(_onCancelRequested);
    on<BankSlipReverseRequested>(_onReverseRequested);
    on<BankSlipRegisterRequested>(_onRegisterRequested);
    on<BankSlipRefreshRequested>(_onRefreshRequested);
    on<BankSlipPdfRequested>(_onPdfRequested);
    on<BankSlipBankSyncRequested>(_onBankSyncRequested);
  }

  final BankSlipGetlist getlist;
  final BankSlipGet     get;
  final BankSlipIssue   issue;
  final BankSlipSettle  settle;
  final BankSlipCancel  cancel;
  final BankSlipReverse reverse;
  final BankSlipRegister register;
  final BankSlipRefresh  refresh;
  final BankSlipPdf      pdf;
  final BankSlipBankSync bankSync;

  /// Aba/filtro/página vigentes (eventos com campo null os mantêm) — a
  /// volta do detalhe devolve o usuário exatamente onde estava.
  String _status   = BankSlipStatus.open;
  String _filter   = '';
  int    _page     = 1;
  int?   _pageSize;

  Future<void> _reloadList(Emitter<BankSlipState> emit) async {
    emit(BankSlipListState(
        loading: true, status: _status, filter: _filter, page: _page));
    final result =
        await getlist(_status, _filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(BankSlipActionFailure(failure));
        emit(BankSlipListState(status: _status, filter: _filter));
      },
      (paged) async {
        // Página esvaziou (ex.: último boleto da página mudou de estado)
        // → recua para a última página existente.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reloadList(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API — D4/D5).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(BankSlipListState(
          items: paged.items,
          status: _status,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  /// Carrega o detalhe; [previous] mantém o cabeçalho visível (saving)
  /// enquanto recarrega após uma ação. Falha ao carregar → volta à lista.
  Future<void> _loadDetail(int id, Emitter<BankSlipState> emit,
      {BankSlipFull? previous}) async {
    if (previous != null) {
      emit(BankSlipDetailState(slip: previous, saving: true));
    } else {
      emit(const BankSlipDetailLoadingState());
    }
    final result = await get(id);
    await result.fold(
      (failure) async {
        emit(BankSlipActionFailure(failure));
        await _reloadList(emit);
      },
      (slip) async => emit(BankSlipDetailState(slip: slip)),
    );
  }

  Future<void> _onListRequested(
      BankSlipListRequested event, Emitter<BankSlipState> emit) async {
    _status = event.status ?? _status;
    _filter = event.filter ?? _filter;
    // Filtro/aba/tamanho novos voltam à página 1 (default do evento); só
    // a navegação da barra manda outra página.
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reloadList(emit);
  }

  Future<void> _onViewRequested(
          BankSlipViewRequested event, Emitter<BankSlipState> emit) =>
      _loadDetail(event.id, emit);

  Future<void> _onBackToList(
          BankSlipBackToListPressed event, Emitter<BankSlipState> emit) =>
      _reloadList(emit);

  /// Emissão: sucesso → SnackBar com o nosso número e ABRE o detalhe do
  /// boleto recém-emitido (a volta cai na aba Abertos, página 1).
  Future<void> _onIssueRequested(
      BankSlipIssueRequested event, Emitter<BankSlipState> emit) async {
    emit(BankSlipListState(
        loading: true, status: _status, filter: _filter, page: _page));
    final result = await issue(event.input);
    await result.fold(
      (failure) async {
        emit(BankSlipActionFailure(failure));
        await _reloadList(emit);
      },
      (issued) async {
        emit(BankSlipActionSuccess('forms.bankSlip.issued',
            args: [issued.ourNumber]));
        _status = BankSlipStatus.open;
        _page = 1;
        await _loadDetail(issued.id, emit);
      },
    );
  }

  /// Ação sobre o boleto do detalhe: executa e RECARREGA o detalhe (o
  /// estado derivado e a linha do tempo vêm do servidor). [run] devolve o
  /// one-shot de sucesso já montado (chave + args).
  Future<void> _runDetailAction(
    BankSlipFull slip,
    Emitter<BankSlipState> emit,
    Future<Either<Failure, BankSlipActionSuccess>> Function() run,
  ) async {
    emit(BankSlipDetailState(slip: slip, saving: true));
    final result = await run();
    // 409 de máquina de estados (BANK_SLIP_NOT_OPEN / NOT_SETTLED) chega
    // como Left — a ponte o apresenta como validação com a mensagem da
    // API; em ambos os casos o detalhe recarrega para refletir o estado
    // REAL do servidor.
    emit(result.fold((failure) => BankSlipActionFailure(failure), (ok) => ok));
    await _loadDetail(slip.id, emit, previous: slip);
  }

  Future<void> _onSettleRequested(
          BankSlipSettleRequested event, Emitter<BankSlipState> emit) =>
      _runDetailAction(event.slip, emit, () async {
        final result =
            await settle(event.slip.id, event.paidValue, event.dtPayment);
        return result.map((settled) => BankSlipActionSuccess(
            'forms.bankSlip.settledDone',
            args: ['${settled.settledCode}']));
      });

  Future<void> _onCancelRequested(
          BankSlipCancelRequested event, Emitter<BankSlipState> emit) =>
      _runDetailAction(event.slip, emit, () async {
        final result = await cancel(event.slip.id, event.note);
        return result.map(
            (_) => const BankSlipActionSuccess('forms.bankSlip.cancelledDone'));
      });

  Future<void> _onReverseRequested(
          BankSlipReverseRequested event, Emitter<BankSlipState> emit) =>
      _runDetailAction(event.slip, emit, () async {
        final result = await reverse(event.slip.id, event.reason);
        return result.map((rev) => BankSlipActionSuccess(
            'forms.bankSlip.reversedDone',
            args: ['${rev.reversed}']));
      });

  // ---------------------------------------------------------------------
  // Onda 2 — o boleto no BANCO (D-I5…D-I10)
  // ---------------------------------------------------------------------

  /// Apresenta ao banco; sucesso mostra o codigoSolicitacao e recarrega (a
  /// linha digitável chega na consulta seguinte — emissão assíncrona).
  Future<void> _onRegisterRequested(
          BankSlipRegisterRequested event, Emitter<BankSlipState> emit) =>
      _runDetailAction(event.slip, emit, () async {
        final result = await register(event.slip.id);
        return result.map((r) => BankSlipActionSuccess(
            'forms.bankSlip.registeredDone', args: [r.requestCode]));
      });

  /// Consulta o banco: mudou → diz a situação; igual → "sem novidade".
  Future<void> _onRefreshRequested(
          BankSlipRefreshRequested event, Emitter<BankSlipState> emit) =>
      _runDetailAction(event.slip, emit, () async {
        final result = await refresh(event.slip.id);
        return result.map((r) => r.changed
            ? BankSlipActionSuccess('forms.bankSlip.refreshedChanged', args: [r.bankStatus])
            : BankSlipActionSuccess('forms.bankSlip.refreshedSame', args: [r.bankStatus]));
      });

  /// PDF oficial: one-shot [BankSlipPdfReady] — a página abre em nova aba.
  Future<void> _onPdfRequested(
      BankSlipPdfRequested event, Emitter<BankSlipState> emit) async {
    emit(BankSlipDetailState(slip: event.slip, saving: true));
    final result = await pdf(event.slip.id);
    emit(result.fold((failure) => BankSlipActionFailure(failure),
        (base64) => BankSlipPdfReady(base64)));
    emit(BankSlipDetailState(slip: event.slip));
  }

  /// Consulta ativa THROTTLED (gatilho da Onda 2): roda silenciosa ao abrir a
  /// tela e com resumo quando o operador pede; depois recarrega a lista.
  Future<void> _onBankSyncRequested(
      BankSlipBankSyncRequested event, Emitter<BankSlipState> emit) async {
    final result = await bankSync();
    result.fold(
      (failure) {
        // banco fora/limite ao abrir a tela não pode virar dialog — só quando pedido
        if (event.announce) emit(BankSlipActionFailure(failure));
      },
      (report) {
        if (event.announce || report.changed > 0) {
          emit(BankSlipActionSuccess('forms.bankSlip.bankSyncDone',
              args: ['${report.checked}', '${report.changed}']));
        }
      },
    );
    await _reloadList(emit);
  }
}
