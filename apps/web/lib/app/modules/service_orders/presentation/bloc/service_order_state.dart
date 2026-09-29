part of 'service_order_bloc.dart';

sealed class ServiceOrderState extends Equatable {
  const ServiceOrderState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — a aba ativa vem em [status] ('A'|'F').
/// Paginação D3: além dos itens da página, o estado carrega filtro
/// aplicado + metadados — a página monta a [RegisterPagingBar] no rodapé.
class ServiceOrderListState extends ServiceOrderState {
  const ServiceOrderListState({
    this.items = const [],
    this.loading = false,
    this.status = 'A',
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<ServiceOrderListItem> items;
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

/// Modo detalhe da OS (buildável). [saving] desabilita as ações enquanto
/// uma operação (item/cancelar/faturar/transmitir) está em andamento.
///
/// Onda 3: na OS FATURADA o detalhe carrega junto a visão FISCAL da nota
/// ([fiscal] — transmissões + voz do fisco). Quando o GET fiscal falha
/// (API fora, endpoint ainda não montado) a OS continua legível e a seção
/// "No fisco" mostra o motivo em [fiscalFailure] em vez de derrubar a tela.
/// OS aberta: os dois ficam null (não há nota).
class ServiceOrderDetailState extends ServiceOrderState {
  const ServiceOrderDetailState({
    required this.order,
    this.saving = false,
    this.fiscal,
    this.fiscalFailure,
  });

  final ServiceOrderFull order;
  final bool saving;
  final ServiceOrderFiscalView? fiscal;
  final Failure? fiscalFailure;

  @override
  List<Object?> get props => [order, saving, fiscal, fiscalFailure];
}

/// One-shot (listener-only): XML autorizado da NFS-e — a página abre em
/// nova aba (Onda 3).
class ServiceOrderFiscalXmlReady extends ServiceOrderState {
  const ServiceOrderFiscalXmlReady(this.xml);
  final String xml;

  @override
  List<Object?> get props => [xml];
}

/// One-shot (listener-only): DANFSe em base64 — a página abre em nova aba
/// como o PDF do boleto (Onda 3).
class ServiceOrderFiscalDanfseReady extends ServiceOrderState {
  const ServiceOrderFiscalDanfseReady(this.pdfBase64);
  final String pdfBase64;

  @override
  List<Object?> get props => [pdfBase64];
}

/// One-shot (listener-only): avisos NÃO bloqueantes do cancelamento da
/// NFS-e (`warnings[]` da API) — a página mostra pela ponte como aviso.
class ServiceOrderFiscalWarnings extends ServiceOrderState {
  const ServiceOrderFiscalWarnings(this.warnings);
  final List<String> warnings;

  @override
  List<Object?> get props => [warnings];
}

/// One-shot (listener-only): notas faturadas SEM NFS-e — a página confirma
/// com o operador ("N notas sem NFS-e — transmitir agora?") antes de
/// disparar o lote. Lista vazia = nada a transmitir.
class ServiceOrderFiscalPendingLoaded extends ServiceOrderState {
  const ServiceOrderFiscalPendingLoaded(this.pending);
  final List<ServiceOrderFiscalPending> pending;

  @override
  List<Object?> get props => [pending];
}

/// One-shot (listener-only): relatório AGREGADO do lote de transmissão —
/// a página resume transmitidas/recusadas pela ponte.
class ServiceOrderFiscalBatchDone extends ServiceOrderState {
  const ServiceOrderFiscalBatchDone(this.report);
  final FiscalTransmitBatchReport report;

  @override
  List<Object?> get props => [report];
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
/// Efeito one-shot do LOTE (D6/D7) — a página abre o relatório: uma linha
/// por ordem, com o motivo das recusadas.
class ServiceOrderBatchInvoiceDone extends ServiceOrderState {
  const ServiceOrderBatchInvoiceDone(this.report);
  final BatchInvoiceReport report;

  @override
  List<Object?> get props => [report];
}

class ServiceOrderMonthlyRunDone extends ServiceOrderState {
  const ServiceOrderMonthlyRunDone(this.report);
  final MonthlyRunReport report;

  @override
  List<Object?> get props => [report];
}
