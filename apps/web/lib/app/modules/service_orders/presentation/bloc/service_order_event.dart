part of 'service_order_bloc.dart';

sealed class ServiceOrderEvent extends Equatable {
  const ServiceOrderEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a lista da aba [status] ('A' abertas | 'F' faturadas) com o
/// [filter] de nome de cliente — a consulta é SEMPRE da API (tela de
/// processo: o status muda no servidor). Paginação D3: [page] navega
/// (troca de aba/filtro novo SEMPRE volta à página 1 — o default);
/// [pageSize] null mantém o tamanho corrente (1º load = config page_size
/// resolvida pela API — D4).
class ServiceOrderListRequested extends ServiceOrderEvent {
  const ServiceOrderListRequested({
    this.status,
    this.filter,
    this.page = 1,
    this.pageSize,
    this.criteria,
  });

  /// Pesquisa avançada (D-BA6/D-BA8): null MANTÉM os critérios correntes.
  final SearchCriteriaValues? criteria;

  /// null = mantém a aba atual do bloc.
  final String? status;

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [status, filter, page, pageSize, criteria];
}

/// FAB "Abrir OS": POST com o cliente escolhido no lookup — 409 (cliente
/// já tem ordem aberta) vira dialog de validação com a mensagem da API,
/// via ponte; sucesso abre o detalhe da OS nova.
class ServiceOrderOpenRequested extends ServiceOrderEvent {
  const ServiceOrderOpenRequested(this.customerId);
  final int customerId;

  @override
  List<Object?> get props => [customerId];
}

/// Tap na linha: carrega a OS completa (GET /:id) e abre o detalhe.
class ServiceOrderViewRequested extends ServiceOrderEvent {
  const ServiceOrderViewRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do detalhe para a lista (recarrega a aba atual).
class ServiceOrderBackToListPressed extends ServiceOrderEvent {
  const ServiceOrderBackToListPressed();
}

/// Cancela a OS ABERTA (DELETE — confirmação já feita pela página).
class ServiceOrderCancelRequested extends ServiceOrderEvent {
  const ServiceOrderCancelRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Inclui ([itemId] null) ou altera um item — o detalhe é recarregado
/// (o totalizer é recalculado no servidor).
class ServiceOrderItemSaveRequested extends ServiceOrderEvent {
  const ServiceOrderItemSaveRequested({
    required this.orderId,
    this.itemId,
    required this.input,
  });

  final int orderId;
  final int? itemId;
  final ServiceOrderItemInput input;

  @override
  List<Object?> get props => [orderId, itemId, input];
}

/// Remove um item da OS aberta (confirmação já feita pela página).
class ServiceOrderItemRemoveRequested extends ServiceOrderEvent {
  const ServiceOrderItemRemoveRequested({
    required this.orderId,
    required this.itemId,
  });

  final int orderId;
  final int itemId;

  @override
  List<Object?> get props => [orderId, itemId];
}

/// Rotina Mensal (D8): POST /monthly-run — o relatório volta no one-shot
/// [ServiceOrderMonthlyRunDone] e a lista é recarregada.
class ServiceOrderMonthlyRunRequested extends ServiceOrderEvent {
  const ServiceOrderMonthlyRunRequested({
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  List<Object?> get props => [year, month];
}

/// Gerar Faturamento da OS aberta — sucesso mostra o nº da fatura e volta
/// para a lista na aba Faturadas.
/// LOTE da cobrança mensal (D6/D7): as ordens SELECIONADAS na aba Abertas,
/// com as MESMAS condições. Quem precisa de forma diferente faz dois lotes.
class ServiceOrderBatchInvoiceRequested extends ServiceOrderEvent {
  const ServiceOrderBatchInvoiceRequested({
    required this.orderIds,
    required this.input,
  });

  final List<int> orderIds;
  final ServiceOrderInvoiceInput input;

  @override
  List<Object?> get props => [orderIds, input];
}

class ServiceOrderInvoiceRequested extends ServiceOrderEvent {
  const ServiceOrderInvoiceRequested({
    required this.orderId,
    required this.input,
  });

  final int orderId;
  final ServiceOrderInvoiceInput input;

  @override
  List<Object?> get props => [orderId, input];
}

// ---------------------------------------------------------------------
// F2b — a NFS-e na nfse-api + os fatos do ERP (seção "No fisco")
// ---------------------------------------------------------------------

/// "Transmitir" (nfse-api): 201 = autorizada; 422/409 com a mensagem; 502/503
/// ou rede = desfecho DESCONHECIDO — o detalhe RELÊ e o aviso diz "consulte".
class ServiceOrderTransmitRequested extends ServiceOrderEvent {
  const ServiceOrderTransmitRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "Consultar" (nfse-api — consulta ativa ao fisco).
class ServiceOrderFiscalRefreshRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalRefreshRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "Reconferir" (nfse-api — D-F109): o plano pediu a prova de que a NFS-e do
/// envio interrompido não existe. Depois o detalhe relê (e o plano decide).
class ServiceOrderFiscalReconfirmRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalReconfirmRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "XML" → one-shot [ServiceOrderFiscalXmlReady].
class ServiceOrderFiscalXmlRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalXmlRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "DANFSe" → one-shot [ServiceOrderFiscalDanfseReady].
class ServiceOrderFiscalDanfseRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalDanfseRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// 1º passo de QUALQUER cancelamento da nota ("Cancelar nota", "Cancelar
/// NFS-e", "Aplicar o cancelamento na nota" — D-F140): lê o PLANO (ERP) e o
/// devolve no one-shot [ServiceOrderCancelPlanReady]; quem decide o passo
/// seguinte é o plano (a página só traduz).
class ServiceOrderCancelFlowRequested extends ServiceOrderEvent {
  const ServiceOrderCancelFlowRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// 2º passo (motivo confirmado): a SAGA do cancelamento (D-F139) — com
/// [atAuthority] o fisco cancela PRIMEIRO (só quando o plano disse que a
/// NFS-e autorizada é o único impedimento), depois a nota no ERP.
class ServiceOrderCancelConfirmed extends ServiceOrderEvent {
  const ServiceOrderCancelConfirmed({
    required this.orderId,
    required this.reason,
    required this.atAuthority,
  });
  final int orderId;
  final String reason;
  final bool atAuthority;

  @override
  List<Object?> get props => [orderId, reason, atAuthority];
}

/// D-F67 "Manter a nota" (motivo já confirmado no dialog): o efeito é
/// `decide` (NFS-e SUBSTITUÍDA no fisco) e o humano decide NÃO cancelar.
class ServiceOrderFiscalCancelWaiverRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalCancelWaiverRequested({
    required this.orderId,
    required this.reason,
  });
  final int orderId;
  final String reason;

  @override
  List<Object?> get props => [orderId, reason];
}

/// "Transmitir notas sem NFS-e" (aba Faturadas), 1º passo: a lista
/// FOTOGRAFADA (todas as páginas da nfse-api, só da OS — D-F145) → one-shot
/// [ServiceOrderFiscalPendingLoaded] para a página confirmar.
class ServiceOrderFiscalPendingRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalPendingRequested();
}

/// 2º passo (confirmado): UMA nota por vez, no app; para em erro sistêmico
/// → one-shot [ServiceOrderFiscalBatchDone]. Um lote por vez.
class ServiceOrderFiscalTransmitBatchRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalTransmitBatchRequested(this.orderIds);
  final List<int> orderIds;

  @override
  List<Object?> get props => [orderIds];
}

