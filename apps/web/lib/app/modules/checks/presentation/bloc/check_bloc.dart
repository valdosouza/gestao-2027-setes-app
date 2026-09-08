import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/check_entity.dart';
import '../../domain/usecase/check_deposit.dart';
import '../../domain/usecase/check_discount.dart';
import '../../domain/usecase/check_get.dart';
import '../../domain/usecase/check_getlist.dart';
import '../../domain/usecase/check_pay.dart';
import '../../domain/usecase/check_return_good.dart';
import '../../domain/usecase/check_return_refund.dart';
import '../../domain/usecase/check_return_to_origin.dart';
import '../../domain/usecase/check_reverse.dart';

part 'check_event.dart';
part 'check_state.dart';

/// Orquestra a tela de Cheques (TELA DE PROCESSO —
/// prompt_cheque_rastreabilidade.md D1–D10 + D7a–c): lista por estado
/// DERIVADO (6 abas, `?status=`), detalhe dirigido pelo estado e as 7 ações
/// que portam o cheque de um estado a outro — depositar (B), descontar (D),
/// retorno com reembolso (T), retorno bom (F), usar em pagamento (P),
/// devolver (V) e estornar o último evento (X). Toda ação chama a API e
/// RECARREGA o detalhe (o estado e a linha do tempo são do servidor).
/// Falhas carregam o [Failure] INTEIRO no one-shot (Framework de
/// Mensagens): a página entrega à PONTE, que deriva o canal — os 409 de
/// máquina de estados viram dialog de validação com a mensagem da API.
class CheckBloc extends Bloc<CheckEvent, CheckState> {
  CheckBloc({
    required this.getlist,
    required this.get,
    required this.deposit,
    required this.discount,
    required this.returnRefund,
    required this.returnGood,
    required this.pay,
    required this.returnToOrigin,
    required this.reverse,
  }) : super(const CheckListState(loading: true)) {
    on<CheckListRequested>(_onListRequested);
    on<CheckViewRequested>(_onViewRequested);
    on<CheckBackToListPressed>(_onBackToList);
    on<CheckDepositRequested>(_onDepositRequested);
    on<CheckDiscountRequested>(_onDiscountRequested);
    on<CheckReturnRefundRequested>(_onReturnRefundRequested);
    on<CheckReturnGoodRequested>(_onReturnGoodRequested);
    on<CheckPayRequested>(_onPayRequested);
    on<CheckReturnRequested>(_onReturnRequested);
    on<CheckReverseRequested>(_onReverseRequested);
  }

  final CheckGetlist getlist;
  final CheckGet get;
  final CheckDeposit deposit;
  final CheckDiscount discount;
  final CheckReturnRefund returnRefund;
  final CheckReturnGood returnGood;
  final CheckPay pay;
  final CheckReturnToOrigin returnToOrigin;
  final CheckReverse reverse;

  /// Aba/filtro/página vigentes (eventos com campo null os mantêm) — a
  /// volta do detalhe devolve o usuário exatamente onde estava.
  String _status = CheckStatus.custody;
  String _filter = '';
  int    _page = 1;
  int?   _pageSize;

  Future<void> _reloadList(Emitter<CheckState> emit) async {
    emit(CheckListState(
        loading: true, status: _status, filter: _filter, page: _page));
    final result =
        await getlist(_status, _filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(CheckActionFailure(failure));
        emit(CheckListState(status: _status, filter: _filter));
      },
      (paged) async {
        // Página esvaziou (ex.: último cheque da página mudou de estado)
        // → recua para a última página existente.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reloadList(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(CheckListState(
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
  Future<void> _loadDetail(int id, Emitter<CheckState> emit,
      {CheckFull? previous}) async {
    if (previous != null) {
      emit(CheckDetailState(check: previous, saving: true));
    } else {
      emit(const CheckDetailLoadingState());
    }
    final result = await get(id);
    await result.fold(
      (failure) async {
        emit(CheckActionFailure(failure));
        await _reloadList(emit);
      },
      (check) async => emit(CheckDetailState(check: check)),
    );
  }

  Future<void> _onListRequested(
      CheckListRequested event, Emitter<CheckState> emit) async {
    _status = event.status ?? _status;
    _filter = event.filter ?? _filter;
    // Filtro/aba/tamanho novos voltam à página 1 (default do evento); só
    // a navegação da barra manda outra página.
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reloadList(emit);
  }

  Future<void> _onViewRequested(
          CheckViewRequested event, Emitter<CheckState> emit) =>
      _loadDetail(event.id, emit);

  Future<void> _onBackToList(
          CheckBackToListPressed event, Emitter<CheckState> emit) =>
      _reloadList(emit);

  /// Ação sobre o cheque do detalhe: executa e RECARREGA o detalhe (o
  /// estado derivado e a linha do tempo vêm do servidor). [run] devolve o
  /// one-shot de sucesso já montado (chave + args).
  Future<void> _runDetailAction(
    CheckFull check,
    Emitter<CheckState> emit,
    Future<Either<Failure, CheckActionSuccess>> Function() run,
  ) async {
    emit(CheckDetailState(check: check, saving: true));
    final result = await run();
    // 409 de máquina de estados (CHECK_NOT_IN_CUSTODY / CHECK_NOT_DISCOUNTED /
    // CHECK_ALREADY_MOVED / CHECK_EVENT_NOT_REVERSIBLE...) chega como Left —
    // a ponte o apresenta como validação com a mensagem da API; em ambos os
    // casos o detalhe recarrega para refletir o estado REAL do servidor.
    emit(result.fold((failure) => CheckActionFailure(failure), (ok) => ok));
    await _loadDetail(check.id, emit, previous: check);
  }

  Future<void> _onDepositRequested(
          CheckDepositRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result =
            await deposit(event.check.id, event.dtRecord, event.bankAccountId);
        return result.map((settled) => CheckActionSuccess(
            'forms.checks.depositedDone', args: ['${settled.settledCode}']));
      });

  Future<void> _onDiscountRequested(
          CheckDiscountRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result = await discount(event.check.id, event.dtRecord,
            event.factoringEntityId, event.bankAccountId, event.feeValue);
        return result.map((settled) => CheckActionSuccess(
            'forms.checks.discountedDone', args: ['${settled.settledCode}']));
      });

  Future<void> _onReturnRefundRequested(
          CheckReturnRefundRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result = await returnRefund(
            event.check.id, event.dtRecord, event.bankAccountId);
        return result.map((settled) => CheckActionSuccess(
            'forms.checks.returnRefundDone',
            args: ['${settled.settledCode}']));
      });

  Future<void> _onReturnGoodRequested(
          CheckReturnGoodRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result = await returnGood(event.check.id, event.note);
        return result.map(
            (_) => const CheckActionSuccess('forms.checks.returnGoodDone'));
      });

  Future<void> _onPayRequested(
          CheckPayRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result = await pay(
            event.check.id, event.dtRecord, event.orderId, event.parcel);
        return result.map((settled) => CheckActionSuccess(
            'forms.checks.paidDone', args: ['${settled.settledCode}']));
      });

  Future<void> _onReturnRequested(
          CheckReturnRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result = await returnToOrigin(
            event.check.id, event.dtRecord, event.note);
        return result.map((returned) => CheckActionSuccess(
            'forms.checks.returnedDone', args: ['${returned.orderId}']));
      });

  Future<void> _onReverseRequested(
          CheckReverseRequested event, Emitter<CheckState> emit) =>
      _runDetailAction(event.check, emit, () async {
        final result =
            await reverse(event.check.id, event.event, event.reason);
        return result.map((rev) => CheckActionSuccess(
            'forms.checks.reversedDone',
            args: ['${rev.affectedCheckIds.length}']));
      });
}
