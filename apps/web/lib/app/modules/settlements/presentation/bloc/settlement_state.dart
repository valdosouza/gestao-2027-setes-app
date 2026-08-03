part of 'settlement_bloc.dart';

sealed class SettlementState extends Equatable {
  const SettlementState();

  @override
  List<Object?> get props => [];
}

/// Aba EM ABERTO (buildável) — PÁGINA da carteira de títulos com saldo
/// derivado + a seleção múltipla VIVA no bloc: [selected] carrega os
/// títulos INTEIROS marcados em qualquer página (a soma e o dialog de
/// baixa não dependem da página visível). Paginação D3: metadados para a
/// RegisterPagingBar do rodapé (null até a primeira resposta da API).
class SettlementBillsState extends SettlementState {
  const SettlementBillsState({
    this.items = const [],
    this.loading = false,
    this.page = 1,
    this.pageSize,
    this.total,
    this.selected = const [],
  });

  final List<SettlementBill> items;
  final bool loading;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  /// Títulos selecionados (TODAS as páginas) — só baixa/estorno limpam.
  final List<SettlementBill> selected;

  /// Chaves selecionadas (orderId-parcel) para as checkboxes da página.
  Set<String> get selectedKeys => {for (final bill in selected) bill.key};

  /// Soma dos saldos selecionados — correta mesmo fora da página visível
  /// (os valores viajam junto das chaves na seleção).
  double get selectedTotal =>
      selected.fold<double>(0, (sum, bill) => sum + bill.balance);

  @override
  List<Object?> get props => [items, loading, page, pageSize, total, selected];
}

/// Aba BAIXADOS (buildável) — PÁGINA das linhas por EVENTO da parcela.
class SettlementSettledState extends SettlementState {
  const SettlementSettledState({
    this.items = const [],
    this.loading = false,
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<SettlementSettled> items;
  final bool loading;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, page, pageSize, total];
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

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7); os 409 de negócio (ex.: "baixa não vigente" do
/// estorno) viram dialog de validação com a mensagem da API e o fields[]
/// do 400 mostra a message do campo apontado.
class SettlementActionFailure extends SettlementState {
  const SettlementActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
