part of 'cashier_bloc.dart';

sealed class CashierState extends Equatable {
  const CashierState();

  @override
  List<Object?> get props => [];
}

/// Painel ÚNICO da tela (buildável) — [cashier] null = SEM sessão aberta
/// (estado vazio com "Abrir Caixa"); [cashier] não-null = painel com saldo
/// ([detail], null enquanto o detalhe carrega). [saving] desabilita as
/// ações durante uma operação (retirar/fechar).
class CashierPanelState extends CashierState {
  const CashierPanelState({
    this.loading = false,
    this.cashier,
    this.detail,
    this.saving = false,
  });

  final bool loading;
  final CashierRow? cashier;
  final CashierDetail? detail;
  final bool saving;

  bool get hasOpenCashier => cashier != null && cashier!.isOpen;

  @override
  List<Object?> get props => [loading, cashier, detail, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave.
class CashierActionSuccess extends CashierState {
  const CashierActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO — a ponte deriva a natureza; os 409 de negócio
/// (CASHIER_ALREADY_OPEN, CASHIER_NOT_OPEN, CASHIER_ALREADY_CLOSED) viram
/// dialog de validação com a mensagem da API.
class CashierActionFailure extends CashierState {
  const CashierActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Fechamento concluído (one-shot) — a página abre o dialog do RELATÓRIO
/// completo (registrado × contado × diferença) com este resultado.
class CashierClosed extends CashierState {
  const CashierClosed(this.result);
  final CashierCloseResult result;

  @override
  List<Object?> get props => [result];
}
