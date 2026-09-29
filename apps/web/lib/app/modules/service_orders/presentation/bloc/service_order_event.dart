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
  });

  /// null = mantém a aba atual do bloc.
  final String? status;

  /// null = mantém o filtro atual do bloc.
  final String? filter;

  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [status, filter, page, pageSize];
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

/// "Cancelar nota" da OS faturada (Q-G16) — motivo já confirmado no dialog.
class ServiceOrderInvoiceCancelRequested extends ServiceOrderEvent {
  const ServiceOrderInvoiceCancelRequested({
    required this.orderId,
    required this.reason,
  });
  final int orderId;
  final String reason;

  @override
  List<Object?> get props => [orderId, reason];
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
// Onda 3 — NFS-e pelo ADN (seção "No fisco" do documento faturado)
// ---------------------------------------------------------------------

/// "Transmitir": POST /api/billing/transmit — o detalhe recarrega depois
/// (a voz do fisco S/A entra na linha do tempo). 422 FISCAL_DPS_REJECTED,
/// 409 e 503 chegam como [ServiceOrderActionFailure] legível pela ponte.
class ServiceOrderTransmitRequested extends ServiceOrderEvent {
  const ServiceOrderTransmitRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "Consultar": POST /fiscal/:orderId/refresh — reconciliação por chave.
class ServiceOrderFiscalRefreshRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalRefreshRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "XML": GET /fiscal/:orderId/xml → one-shot [ServiceOrderFiscalXmlReady].
class ServiceOrderFiscalXmlRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalXmlRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "DANFSe": GET /fiscal/:orderId/danfse → one-shot
/// [ServiceOrderFiscalDanfseReady].
class ServiceOrderFiscalDanfseRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalDanfseRequested(this.orderId);
  final int orderId;

  @override
  List<Object?> get props => [orderId];
}

/// "Cancelar NFS-e" (motivo já confirmado no MESMO dialog do "Cancelar
/// nota"): POST /api/billing/fiscal/cancel. 'C' = nota cancelada no fisco
/// e aqui (a OS volta a aberta); 'K' = pedido em voo (detalhe recarrega e
/// fica bloqueado até a consulta reconciliar).
class ServiceOrderFiscalCancelRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalCancelRequested({
    required this.orderId,
    required this.reason,
  });
  final int orderId;
  final String reason;

  @override
  List<Object?> get props => [orderId, reason];
}

/// "Transmitir pendentes" (aba Faturadas), 1º passo: GET /fiscal/pending →
/// one-shot [ServiceOrderFiscalPendingLoaded] para a página confirmar.
class ServiceOrderFiscalPendingRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalPendingRequested();
}

/// "Transmitir pendentes", 2º passo (confirmado): fatia em blocos de
/// [fiscalTransmitChunkSize], chama /transmit-batch em SEQUÊNCIA e agrega
/// → one-shot [ServiceOrderFiscalBatchDone]. Um lote por vez (H1).
class ServiceOrderFiscalTransmitBatchRequested extends ServiceOrderEvent {
  const ServiceOrderFiscalTransmitBatchRequested(this.orderIds);
  final List<int> orderIds;

  @override
  List<Object?> get props => [orderIds];
}
