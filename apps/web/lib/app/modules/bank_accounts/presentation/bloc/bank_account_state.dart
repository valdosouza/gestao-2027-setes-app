part of 'bank_account_bloc.dart';

sealed class BankAccountState extends Equatable {
  const BankAccountState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — contas bancárias da institution. Paginação D3:
/// além dos itens da página, o estado carrega filtro aplicado + metadados —
/// a página monta a barra da fábrica e reenvia [filter] ao navegar.
class BankAccountListState extends BankAccountState {
  const BankAccountListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<BankAccountListItem> items;
  final bool loading;

  /// Filtro APLICADO (o mesmo usado na recarga pós-salvar/excluir).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, filter, page, pageSize, total];
}

/// Modo formulário (buildável). [editing] null = conta nova.
class BankAccountFormState extends BankAccountState {
  const BankAccountFormState({this.editing, this.saving = false});
  final BankAccountFull? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class BankAccountActionSuccess extends BankAccountState {
  const BankAccountActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class BankAccountActionFailure extends BankAccountState {
  const BankAccountActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
