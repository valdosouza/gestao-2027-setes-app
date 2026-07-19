part of 'service_order_bloc.dart';

sealed class ServiceOrderState extends Equatable {
  const ServiceOrderState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — a aba ativa vem em [status] ('A'|'F').
class ServiceOrderListState extends ServiceOrderState {
  const ServiceOrderListState({
    this.items = const [],
    this.loading = false,
    this.status = 'A',
  });

  final List<ServiceOrderListItem> items;
  final bool loading;
  final String status;

  @override
  List<Object?> get props => [items, loading, status];
}

/// Modo detalhe da OS (buildável). [saving] desabilita as ações enquanto
/// uma operação (item/cancelar/faturar) está em andamento.
class ServiceOrderDetailState extends ServiceOrderState {
  const ServiceOrderDetailState({required this.order, this.saving = false});

  final ServiceOrderFull order;
  final bool saving;

  @override
  List<Object?> get props => [order, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave (ex.: nº da fatura gerada).
class ServiceOrderActionSuccess extends ServiceOrderState {
  const ServiceOrderActionSuccess(this.messageKey, {this.args = const []});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;

  @override
  List<Object?> get props => [messageKey, args];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7); os 409 de negócio (trava D5, ordem faturada) viram
/// dialog de validação com a mensagem da API e o fields[] do 400 ancora a
/// mensagem no campo apontado.
class ServiceOrderActionFailure extends ServiceOrderState {
  const ServiceOrderActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Efeito one-shot com o RELATÓRIO da rotina mensal (listener-only) — a
/// página mostra o dialog de resultado (processados/abertas/injetados/
/// pulados + erros por cliente).
class ServiceOrderMonthlyRunDone extends ServiceOrderState {
  const ServiceOrderMonthlyRunDone(this.report);
  final MonthlyRunReport report;

  @override
  List<Object?> get props => [report];
}
