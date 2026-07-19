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

  /// Filtros vigentes de cada aba (eventos com campo null os mantêm).
  String _billsFilter   = '';
  String _settledFilter = '';
  int    _stAccount     = 0; // 0 = Caixa (default da aba Movimento)
  String? _stFrom;
  String? _stTo;

  Future<void> _reloadBills(Emitter<SettlementState> emit) async {
    emit(const SettlementBillsState(loading: true));
    final result = await billsGetlist('open', '', _billsFilter);
    result.fold(
      (failure) {
        emit(SettlementActionFailure(failure));
        emit(const SettlementBillsState());
      },
      (items) => emit(SettlementBillsState(items: items)),
    );
  }

  Future<void> _reloadSettled(Emitter<SettlementState> emit) async {
    emit(const SettlementSettledState(loading: true));
    final result = await settledGetlist(_settledFilter);
    result.fold(
      (failure) {
        emit(SettlementActionFailure(failure));
        emit(const SettlementSettledState());
      },
      (items) => emit(SettlementSettledState(items: items)),
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
    await _reloadBills(emit);
  }

  Future<void> _onSettleRequested(
      SettlementSettleRequested event, Emitter<SettlementState> emit) async {
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
    await _reloadSettled(emit);
  }

  Future<void> _onReversalRequested(
      SettlementReversalRequested event,
      Emitter<SettlementState> emit) async {
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
