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

/// Efeito one-shot para SnackBar de erro (listener-only) — mensagem da
/// API (inclui os 409 de trava D5 / ordem faturada).
class ServiceOrderActionFailure extends ServiceOrderState {
  const ServiceOrderActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
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
