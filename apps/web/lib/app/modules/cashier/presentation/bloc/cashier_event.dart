part of 'cashier_bloc.dart';

sealed class CashierEvent extends Equatable {
  const CashierEvent();

  @override
  List<Object?> get props => [];
}

/// Carga inicial da tela — GET /current (evento do initState da página).
class CashierStarted extends CashierEvent {
  const CashierStarted();
}

/// Botão "Abrir Caixa" do estado vazio.
class CashierOpenRequested extends CashierEvent {
  const CashierOpenRequested();
}

/// Recarrega a sessão corrente sem trocar de tela (pull-to-refresh/botão
/// de atualizar).
class CashierRefreshRequested extends CashierEvent {
  const CashierRefreshRequested();
}

/// Confirmação do dialog "Retirar/Transferir".
class CashierWithdrawRequested extends CashierEvent {
  const CashierWithdrawRequested(this.input);
  final CashierWithdrawInput input;

  @override
  List<Object?> get props => [input];
}

/// Confirmação do dialog de fechamento — conferência por forma +
/// transferência opcional.
class CashierCloseRequested extends CashierEvent {
  const CashierCloseRequested(this.input);
  final CashierCloseInput input;

  @override
  List<Object?> get props => [input];
}
