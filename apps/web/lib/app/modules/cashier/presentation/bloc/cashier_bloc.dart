import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/cashier_entity.dart';
import '../../domain/usecase/cashier_close.dart';
import '../../domain/usecase/cashier_current_get.dart';
import '../../domain/usecase/cashier_detail_get.dart';
import '../../domain/usecase/cashier_open.dart';
import '../../domain/usecase/cashier_withdraw.dart';

part 'cashier_event.dart';
part 'cashier_state.dart';

/// Orquestra o Caixa — 3º TIPO de tela do produto: SESSÃO/STATUS (não é
/// lista+form nem árvore). Sem sessão aberta → estado vazio com "Abrir
/// Caixa"; com sessão aberta → painel com saldo derivado + formas de
/// pagamento. TODA ação (abrir/retirar/fechar) chama a API e RECARREGA o
/// detalhe — o saldo NUNCA é somado no app. Falhas carregam o [Failure]
/// INTEIRO no one-shot (Framework de Mensagens): a página entrega à PONTE.
class CashierBloc extends Bloc<CashierEvent, CashierState> {
  CashierBloc({
    required this.currentGet,
    required this.open,
    required this.detailGet,
    required this.withdraw,
    required this.closeCashier,
  }) : super(const CashierPanelState(loading: true)) {
    on<CashierStarted>((event, emit) => _loadCurrent(emit));
    on<CashierOpenRequested>(_onOpenRequested);
    on<CashierRefreshRequested>(_onRefreshRequested);
    on<CashierWithdrawRequested>(_onWithdrawRequested);
    on<CashierCloseRequested>(_onCloseRequested);
  }

  final CashierCurrentGet currentGet;
  final CashierOpen       open;
  final CashierDetailGet  detailGet;
  final CashierWithdraw   withdraw;

  // Nome do campo NÃO pode ser `close` — colidiria com Bloc.close().
  final CashierClose      closeCashier;

  /// Sessão corrente — preserva o cabeçalho nos re-emits de saving/falha
  /// sem precisar de uma nova consulta a /current.
  CashierRow? _cashier;

  Future<void> _loadCurrent(Emitter<CashierState> emit) async {
    emit(const CashierPanelState(loading: true));
    final result = await currentGet();
    await result.fold(
      (failure) async {
        emit(CashierActionFailure(failure));
        _cashier = null;
        emit(const CashierPanelState());
      },
      (cashier) async {
        _cashier = cashier;
        if (cashier == null || !cashier.isOpen) {
          emit(const CashierPanelState());
          return;
        }
        await _loadDetail(cashier, emit);
      },
    );
  }

  Future<void> _loadDetail(CashierRow cashier, Emitter<CashierState> emit) async {
    emit(CashierPanelState(loading: true, cashier: cashier));
    final result = await detailGet(cashier.id);
    await result.fold(
      (failure) async {
        emit(CashierActionFailure(failure));
        emit(CashierPanelState(cashier: cashier));
      },
      (detail) async {
        _cashier = detail.cashier;
        emit(CashierPanelState(cashier: detail.cashier, detail: detail));
      },
    );
  }

  Future<void> _onOpenRequested(
      CashierOpenRequested event, Emitter<CashierState> emit) async {
    emit(const CashierPanelState(loading: true));
    final result = await open();
    await result.fold(
      (failure) async {
        emit(CashierActionFailure(failure));
        await _loadCurrent(emit);
      },
      (cashier) async {
        _cashier = cashier;
        emit(const CashierActionSuccess('forms.cashier.opened'));
        await _loadDetail(cashier, emit);
      },
    );
  }

  Future<void> _onRefreshRequested(
      CashierRefreshRequested event, Emitter<CashierState> emit) async {
    final cashier = _cashier;
    if (cashier == null) {
      await _loadCurrent(emit);
    } else {
      await _loadDetail(cashier, emit);
    }
  }

  Future<void> _onWithdrawRequested(
      CashierWithdrawRequested event, Emitter<CashierState> emit) async {
    final cashier = _cashier;
    if (cashier == null) return;
    emit(CashierPanelState(cashier: cashier, saving: true));
    final result = await withdraw(cashier.id, event.input);
    await result.fold(
      (failure) async {
        emit(CashierActionFailure(failure));
        await _loadDetail(cashier, emit);
      },
      (_) async {
        emit(const CashierActionSuccess('forms.cashier.withdrawn'));
        await _loadDetail(cashier, emit);
      },
    );
  }

  Future<void> _onCloseRequested(
      CashierCloseRequested event, Emitter<CashierState> emit) async {
    final cashier = _cashier;
    if (cashier == null) return;
    emit(CashierPanelState(cashier: cashier, saving: true));
    final result = await closeCashier(cashier.id, event.input);
    await result.fold(
      (failure) async {
        emit(CashierActionFailure(failure));
        await _loadDetail(cashier, emit);
      },
      (closeResult) async {
        // One-shot com o RELATÓRIO completo — a página abre o dialog de
        // resultado (nunca só "ok"). Depois volta ao estado vazio (a
        // sessão fechou).
        emit(CashierClosed(closeResult));
        _cashier = null;
        await _loadCurrent(emit);
      },
    );
  }
}
