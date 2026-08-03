import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/settlement_entity.dart';
import '../../domain/usecase/settlement_bills_getlist.dart';
import '../../domain/usecase/settlement_reversal.dart';
import '../../domain/usecase/settlement_settle.dart';
import '../../domain/usecase/settlement_settled_getlist.dart';
import '../../domain/usecase/settlement_statements_get.dart';

part 'settlement_event.dart';
part 'settlement_state.dart';

/// Orquestra a Baixa de Títulos — 2ª TELA DE PROCESSO do produto (Módulo
/// Software House, Onda 5): 3 abas (Em aberto × Baixados × Movimento).
/// Toda ação (baixa em lote, estorno) chama a API e RECARREGA a aba — o
/// saldo do título e os totais do extrato são DERIVADOS no servidor;
/// financeiro NÃO se apaga (estorno = lançamento inverso). Falhas carregam
/// o [Failure] INTEIRO no one-shot (Framework de Mensagens): a página
/// entrega à PONTE, que deriva o canal — os 409 de negócio viram dialog de
/// validação com a mensagem da API.
class SettlementBloc extends Bloc<SettlementEvent, SettlementState> {
  SettlementBloc({
    required this.billsGetlist,
    required this.settle,
    required this.settledGetlist,
    required this.reversal,
    required this.statementsGet,
  }) : super(const SettlementBillsState(loading: true)) {
    on<SettlementBillsRequested>(_onBillsRequested);
    on<SettlementBillToggled>(_onBillToggled);
    on<SettlementSettleRequested>(_onSettleRequested);
    on<SettlementSettledRequested>(_onSettledRequested);
    on<SettlementReversalRequested>(_onReversalRequested);
    on<SettlementStatementsRequested>(_onStatementsRequested);
  }

  final SettlementBillsGetlist   billsGetlist;
  final SettlementSettle         settle;
  final SettlementSettledGetlist settledGetlist;
  final SettlementReversal       reversal;
  final SettlementStatementsGet  statementsGet;

  /// Filtros vigentes de cada aba (eventos com campo null os mantêm) +
  /// página/tamanho correntes (paginação D3 — recarga pós-ação devolve o
  /// usuário exatamente onde estava).
  String _billsFilter   = '';
  int    _billsPage     = 1;
  int?   _billsPageSize;
  String _settledFilter = '';
  int    _settledPage   = 1;
  int?   _settledPageSize;
  int    _stAccount     = 0; // 0 = Caixa (default da aba Movimento)
  String? _stFrom;
  String? _stTo;

  /// Seleção múltipla da aba Em aberto — vive no BLOC (não na página):
  /// sobrevive à navegação de página E à troca de filtro (o usuário pode
  /// marcar títulos em páginas diferentes para a MESMA baixa em lote).
  /// Guarda o título INTEIRO por chave (orderId-parcel): soma e dialog de
  /// baixa corretos mesmo com seleção fora da página visível. SÓ as ações
  /// de baixa/estorno limpam.
  final Map<String, SettlementBill> _selected = {};

  /// Última página carregada da carteira — permite re-emitir a lista nos
  /// toggles de seleção sem nova consulta.
  PagedResult<SettlementBill>? _billsLoaded;

  SettlementBillsState _billsState({bool loading = false}) {
    final paged = _billsLoaded;
    return SettlementBillsState(
      items: paged?.items ?? const [],
      loading: loading,
      page: paged?.page ?? _billsPage,
      pageSize: paged?.pageSize,
      total: paged?.total,
      selected: List.unmodifiable(_selected.values),
    );
  }

  Future<void> _reloadBills(Emitter<SettlementState> emit) async {
    emit(SettlementBillsState(
        loading: true, selected: List.unmodifiable(_selected.values)));
    final result = await billsGetlist('open', '', _billsFilter,
        page: _billsPage, pageSize: _billsPageSize);
    await result.fold(
      (failure) async {
        emit(SettlementActionFailure(failure));
        _billsLoaded = null;
        emit(_billsState());
      },
      (paged) async {
        // Página esvaziou (ex.: baixa total sumiu com os títulos) → recua
        // para a última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _billsPage = paged.pageCount;
          return _reloadBills(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API — D4/D5).
        _billsPage = paged.page;
        _billsPageSize = paged.pageSize;
        _billsLoaded = paged;
        // Atualiza o objeto guardado dos selecionados que reapareceram na
        // página (saldo pode ter mudado no servidor) — a seleção em si é
        // preservada.
        for (final bill in paged.items) {
          if (_selected.containsKey(bill.key)) _selected[bill.key] = bill;
        }
        emit(_billsState());
      },
    );
  }

  Future<void> _reloadSettled(Emitter<SettlementState> emit) async {
    emit(const SettlementSettledState(loading: true));
    final result = await settledGetlist(_settledFilter,
        page: _settledPage, pageSize: _settledPageSize);
    await result.fold(
      (failure) async {
        emit(SettlementActionFailure(failure));
        emit(const SettlementSettledState());
      },
      (paged) async {
        // Recuo da página vazia (ex.: filtro novo com menos resultados).
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _settledPage = paged.pageCount;
          return _reloadSettled(emit);
        }
        _settledPage = paged.page;
        _settledPageSize = paged.pageSize;
        emit(SettlementSettledState(
          items: paged.items,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  Future<void> _reloadStatements(Emitter<SettlementState> emit) async {
    emit(const SettlementStatementsState(loading: true));
    final result = await statementsGet(_stAccount, _stFrom, _stTo);
    result.fold(
      (failure) {
        emit(SettlementActionFailure(failure));
        emit(const SettlementStatementsState());
      },
      (report) => emit(SettlementStatementsState(report: report)),
    );
  }

  Future<void> _onBillsRequested(
      SettlementBillsRequested event, Emitter<SettlementState> emit) async {
    _billsFilter = event.filter ?? _billsFilter;
    // Filtro novo/troca de tamanho voltam à página 1 (default do evento);
    // só a navegação da barra manda outra página. A SELEÇÃO não é tocada.
    _billsPage = event.page;
    _billsPageSize = event.pageSize ?? _billsPageSize;
    await _reloadBills(emit);
  }

  /// Marca/desmarca o título — re-emite a página corrente SEM consulta.
  void _onBillToggled(
      SettlementBillToggled event, Emitter<SettlementState> emit) {
    final key = event.bill.key;
    if (_selected.remove(key) == null) _selected[key] = event.bill;
    emit(_billsState());
  }

  Future<void> _onSettleRequested(
      SettlementSettleRequested event, Emitter<SettlementState> emit) async {
    // Ação de BAIXA: única (junto do estorno) que limpa a seleção.
    _selected.clear();
    emit(const SettlementBillsState(loading: true));
    final result = await settle(event.input);
    await result.fold(
      (failure) async {
        emit(SettlementActionFailure(failure));
        await _reloadBills(emit);
      },
      (batch) async {
        emit(SettlementActionSuccess('forms.settlement.settledDone',
            args: ['${batch.settledCode}']));
        await _reloadBills(emit);
      },
    );
  }

  Future<void> _onSettledRequested(
      SettlementSettledRequested event, Emitter<SettlementState> emit) async {
    _settledFilter = event.filter ?? _settledFilter;
    _settledPage = event.page;
    _settledPageSize = event.pageSize ?? _settledPageSize;
    await _reloadSettled(emit);
  }

  Future<void> _onReversalRequested(
      SettlementReversalRequested event,
      Emitter<SettlementState> emit) async {
    // Ação de ESTORNO: devolve título à carteira — limpa a seleção (os
    // saldos guardados poderiam ficar defasados).
    _selected.clear();
    emit(const SettlementSettledState(loading: true));
    final result = await reversal(
        event.orderId, event.parcel, event.event, event.reason);
    await result.fold(
      (failure) async {
        // 409 "baixa não vigente" chega aqui — a ponte o apresenta como
        // dialog de validação com a mensagem da API.
        emit(SettlementActionFailure(failure));
        await _reloadSettled(emit);
      },
      (rev) async {
        emit(SettlementActionSuccess('forms.settlement.reversed',
            args: ['${rev.settledCode}']));
        await _reloadSettled(emit);
      },
    );
  }

  Future<void> _onStatementsRequested(
      SettlementStatementsRequested event,
      Emitter<SettlementState> emit) async {
    _stAccount = event.bankAccountId ?? _stAccount;
    if (event.dtFrom != null) _stFrom = event.dtFrom!.isEmpty ? null : event.dtFrom;
    if (event.dtTo != null) _stTo = event.dtTo!.isEmpty ? null : event.dtTo;
    await _reloadStatements(emit);
  }
}
