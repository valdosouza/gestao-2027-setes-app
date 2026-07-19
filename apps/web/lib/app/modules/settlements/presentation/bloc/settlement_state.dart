part of 'settlement_bloc.dart';

sealed class SettlementState extends Equatable {
  const SettlementState();

  @override
  List<Object?> get props => [];
}

/// Aba EM ABERTO (buildável) — carteira de títulos com saldo derivado.
class SettlementBillsState extends SettlementState {
  const SettlementBillsState({this.items = const [], this.loading = false});

  final List<SettlementBill> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Aba BAIXADOS (buildável) — linha por EVENTO da parcela.
class SettlementSettledState extends SettlementState {
  const SettlementSettledState({this.items = const [], this.loading = false});

  final List<SettlementSettled> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Aba MOVIMENTO (buildável) — extrato com totais prontos da API.
class SettlementStatementsState extends SettlementState {
  const SettlementStatementsState({
    this.report = const SettlementStatementReport(),
    this.loading = false,
  });

  final SettlementStatementReport report;
  final bool loading;

  @override
  List<Object?> get props => [report, loading];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave (ex.: nº do código da baixa gerada).
class SettlementActionSuccess extends SettlementState {
  const SettlementActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot para SnackBar de erro (listener-only) — mensagem da API
/// como veio (inclui o 409 "baixa não vigente" do estorno).
class SettlementActionFailure extends SettlementState {
  const SettlementActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
