part of 'bank_slip_bloc.dart';

sealed class BankSlipState extends Equatable {
  const BankSlipState();

  @override
  List<Object?> get props => [];
}

/// Modo LISTA (buildável) — a aba ativa vem em [status] ('open' |
/// 'settled' | 'cancelled'). Paginação D3: itens da página + filtro
/// aplicado + metadados para a [RegisterPagingBar] do rodapé.
class BankSlipListState extends BankSlipState {
  const BankSlipListState({
    this.items = const [],
    this.loading = false,
    this.status = BankSlipStatus.open,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<BankSlipListRow> items;
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
class BankSlipDetailLoadingState extends BankSlipState {
  const BankSlipDetailLoadingState();
}

/// Modo DETALHE (buildável). [saving] desabilita as ações enquanto uma
/// operação (baixar/cancelar/estornar) ou a recarga está em andamento.
class BankSlipDetailState extends BankSlipState {
  const BankSlipDetailState({required this.slip, this.saving = false});

  final BankSlipFull slip;
  final bool saving;

  @override
  List<Object?> get props => [slip, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave (nosso número, código da baixa...).
class BankSlipActionSuccess extends BankSlipState {
  const BankSlipActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7); os 409 de negócio viram dialog de validação com a
/// mensagem da API e o fields[] do 400 (ex.: dtExpiration do agrupado)
/// mostra a message do campo apontado.
class BankSlipActionFailure extends BankSlipState {
  const BankSlipActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
