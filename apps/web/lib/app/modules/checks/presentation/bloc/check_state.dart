part of 'check_bloc.dart';

sealed class CheckState extends Equatable {
  const CheckState();

  @override
  List<Object?> get props => [];
}

/// Modo LISTA (buildável) — a aba ativa vem em [status] (um dos 6 de
/// [CheckStatus]). Itens da página + filtro aplicado + metadados para
/// a [RegisterPagingBar] do rodapé.
class CheckListState extends CheckState {
  const CheckListState({
    this.items = const [],
    this.loading = false,
    this.status = CheckStatus.custody,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<CheckListRow> items;
  final bool loading;
  final String status;

  /// Filtro APLICADO (o mesmo usado nas recargas do bloc).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props =>
      [items, loading, status, filter, page, pageSize, total];
}

/// Detalhe em carga inicial (buildável) — antes do 1º GET :id.
class CheckDetailLoadingState extends CheckState {
  const CheckDetailLoadingState();
}

/// Modo DETALHE (buildável). [saving] desabilita as ações enquanto uma
/// operação ou a recarga está em andamento.
class CheckDetailState extends CheckState {
  const CheckDetailState({required this.check, this.saving = false});

  final CheckFull check;
  final bool saving;

  @override
  List<Object?> get props => [check, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only).
class CheckActionSuccess extends CheckState {
  const CheckActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO — a ponte deriva a natureza (validation × erro
/// técnico); os 409 de máquina de estados (CHECK_NOT_IN_CUSTODY,
/// CHECK_ALREADY_MOVED...) viram dialog de validação com a mensagem da API.
class CheckActionFailure extends CheckState {
  const CheckActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
