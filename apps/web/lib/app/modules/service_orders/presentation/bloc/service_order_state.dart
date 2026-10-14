part of 'service_order_bloc.dart';

/// CONHECIMENTO NEGATIVO (D-F198 = Q-F197-ADV-02 (a), gate adversarial da Rodada 14; R15-SOC-06): todo estado é `Equatable` e o bloc
/// DESCARTA um estado IGUAL ao último emitido — dois avisos idênticos seguidos (mesma chave, mesmos args, mesma OS) viram UM, e o
/// "último emitido" pode ter aparecido há MINUTOS (um ato que termina fora da OS não emite mais nada: o 2º "Consultar" igual, 3 min
/// depois, não é anunciado). Nenhuma regra pode CONTAR avisos iguais seguidos. D-F211 (= PSO-ADV-06/PSO-SOC-06 (a), gates do passeio
/// logado): com o código curto da D-F205, as falhas de REDE do mesmo serviço ficam IGUAIS (antes a URL as diferenciava) — dois desfechos
/// de rede seguidos de atos DIFERENTES da mesma OS (ex.: XML e DANFSe, com a tela já fora do detalhe) viram UM diálogo; aceito (o texto é o
/// mesmo e o operador repete o ato que quiser).
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
    this.criteria = SearchCriteriaValues.empty,
    this.loadFailed = false,
  });

  final List<ServiceOrderListItem> items;

  /// D-F206 (= P-03 (a), Valdo 2026-10-13 — passeio logado da F2b): a CARGA da lista falhou — a tela mostra o erro com "Tentar
  /// novamente", nunca "Não encontramos nenhum registro" (a falha não é uma lista vazia).
  final bool loadFailed;

  /// Critérios APLICADOS da pesquisa avançada (chips + recarga).
  final SearchCriteriaValues criteria;
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
      [items, loading, status, filter, page, pageSize, total, criteria, loadFailed];
}

/// Modo detalhe da OS (buildável). [saving] desabilita as ações enquanto
/// uma operação (item/cancelar/faturar/transmitir) está em andamento.
///
/// F2b (D-F139): na OS FATURADA a seção "No fisco" tem DUAS fontes e DUAS
/// falhas — a VOZ do fisco ([fiscal], nfse-api) e o EFEITO dela na nota
/// ([effect], ERP). Uma pode falhar sem a outra: a voz indisponível mostra o
/// motivo; o efeito indisponível diz "efeito indisponível" — nunca "nada
/// pendente". OS aberta: tudo null (não há nota).
class ServiceOrderDetailState extends ServiceOrderState {
  const ServiceOrderDetailState({
    required this.order,
    this.saving = false,
    this.fiscal,
    this.fiscalFailure,
    this.effect,
    this.effectFailure,
  });

  final ServiceOrderFull order;
  final bool saving;
  final ServiceOrderFiscalView? fiscal;
  final Failure? fiscalFailure;
  final ServiceOrderFiscalEffect? effect;
  final Failure? effectFailure;

  @override
  List<Object?> get props => [order, saving, fiscal, fiscalFailure, effect, effectFailure];
}

/// One-shot (listener-only): o PLANO de cancelamento lido (D-F140) — a
/// página decide o passo seguinte só por ele (cancelável → motivo; NFS-e
/// autorizada como único impedimento → cancelar no fisco e na nota;
/// reconferir → reconferir; o resto → mostrar os bloqueios).
class ServiceOrderCancelPlanReady extends ServiceOrderState {
  /// [plan] sempre com o `orderId` que a TELA pediu (F2B-ADV-09).
  const ServiceOrderCancelPlanReady(this.plan);
  final ServiceOrderCancelPlan plan;

  @override
  List<Object?> get props => [plan];
}

/// One-shot (listener-only): AVISO informativo do fluxo fiscal (desfecho
/// desconhecido no fisco, veredito da reconferência, o fisco cancelou mas a
/// nota não). [messageKey] é chave i18n; [detail] = a mensagem da API, quando
/// há (já pronta).
class ServiceOrderFiscalNotice extends ServiceOrderState {
  const ServiceOrderFiscalNotice(this.messageKey, {this.args = const [], this.detail, this.orderNumber});
  final String messageKey;
  final List<String> args;
  final String? detail;
  /// D-F182/D-F187: o NÚMERO que a tela mostra da OS (`number ?? id`, nunca a chave interna) quando o desfecho é de um ato cuja tela
  /// SAIU (outra OS aberta ou a lista) — a página o prefixa ("OS N: "); nulo = a tela é a OS do ato.
  final int? orderNumber;

  @override
  List<Object?> get props => [messageKey, args, detail, orderNumber];
}

/// One-shot (listener-only): XML autorizado da NFS-e — a página abre em
/// nova aba (Onda 3).
class ServiceOrderFiscalXmlReady extends ServiceOrderState {
  const ServiceOrderFiscalXmlReady(this.xml, {this.orderNumber});
  final String xml;
  /// D-F189 (Q-F195-ADV-01 (a)): o número da OS quando a tela de agora é OUTRA (o documento abre e a página diz de qual OS é).
  final int? orderNumber;

  @override
  List<Object?> get props => [xml, orderNumber];
}

/// One-shot (listener-only): DANFSe em base64 — a página abre em nova aba
/// como o PDF do boleto (Onda 3).
class ServiceOrderFiscalDanfseReady extends ServiceOrderState {
  const ServiceOrderFiscalDanfseReady(this.pdfBase64, {this.orderNumber});
  final String pdfBase64;
  /// D-F189 (Q-F195-ADV-01 (a)): o número da OS quando a tela de agora é OUTRA (o documento abre e a página diz de qual OS é).
  final int? orderNumber;

  @override
  List<Object?> get props => [pdfBase64, orderNumber];
}

/// One-shot (listener-only): avisos NÃO bloqueantes do cancelamento da
/// NFS-e (`warnings[]` da API) — a página mostra pela ponte como aviso.
class ServiceOrderFiscalWarnings extends ServiceOrderState {
  const ServiceOrderFiscalWarnings(this.warnings, {this.orderNumber});
  final List<String> warnings;
  /// D-F182/D-F187: o NÚMERO que a tela mostra da OS (`number ?? id`, nunca a chave interna) quando o desfecho é de um ato cuja tela
  /// SAIU (outra OS aberta ou a lista) — a página o prefixa ("OS N: "); nulo = a tela é a OS do ato.
  final int? orderNumber;

  @override
  List<Object?> get props => [warnings, orderNumber];
}

/// One-shot (listener-only): notas da OS SEM NFS-e (lista fotografada — D-F145)
/// — a página confirma com o operador antes de disparar o lote. Lista vazia =
/// nada a transmitir.
class ServiceOrderFiscalPendingLoaded extends ServiceOrderState {
  const ServiceOrderFiscalPendingLoaded(this.pending);
  final List<ServiceOrderFiscalPending> pending;

  @override
  List<Object?> get props => [pending];
}

/// One-shot (listener-only): relatório do lote de transmissão (rodou no app,
/// 1 nota por vez — D-F145) — a página resume transmitidas/recusadas e, se o
/// lote PAROU, o motivo.
class ServiceOrderFiscalBatchDone extends ServiceOrderState {
  const ServiceOrderFiscalBatchDone(this.report, {this.noteNumbers = const {}});
  final FiscalTransmitBatchReport report;

  /// D-F187: o nº da NOTA de cada OS do lote (a pendente fotografada o traz) — as linhas se identificam por ele.
  final Map<int, String> noteNumbers;

  @override
  List<Object?> get props => [report, noteNumbers];
}

/// D-F198: um one-shot IGUAL ao último estado emitido é descartado (ver [ServiceOrderState]).
///
/// Efeito one-shot para SnackBar de sucesso (listener-only). [args]
/// alimenta placeholders da chave (ex.: nº da fatura gerada).
class ServiceOrderActionSuccess extends ServiceOrderState {
  const ServiceOrderActionSuccess(this.messageKey, {this.args = const [], this.orderNumber});

  /// Chave i18n — a página traduz.
  final String messageKey;
  final List<String> args;
  /// D-F182/D-F187: o NÚMERO que a tela mostra da OS (`number ?? id`, nunca a chave interna) quando o desfecho é de um ato cuja tela
  /// SAIU (outra OS aberta ou a lista) — a página o prefixa ("OS N: "); nulo = a tela é a OS do ato.
  final int? orderNumber;

  @override
  List<Object?> get props => [messageKey, args, orderNumber];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7); os 409 de negócio (trava D5, ordem faturada) viram
/// dialog de validação com a mensagem da API e o fields[] do 400 ancora a
/// mensagem no campo apontado.
class ServiceOrderActionFailure extends ServiceOrderState {
  const ServiceOrderActionFailure(this.failure, {this.orderNumber});
  final Failure failure;
  /// D-F182/D-F187: o NÚMERO que a tela mostra da OS (`number ?? id`, nunca a chave interna) quando o desfecho é de um ato cuja tela
  /// SAIU (outra OS aberta ou a lista) — a página o prefixa ("OS N: "); nulo = a tela é a OS do ato.
  final int? orderNumber;

  @override
  List<Object?> get props => [failure, orderNumber];
}

/// Efeito one-shot com o RELATÓRIO da rotina mensal (listener-only) — a
/// página mostra o dialog de resultado (processados/abertas/injetados/
/// pulados + erros por cliente).
/// Efeito one-shot do LOTE (D6/D7) — a página abre o relatório: uma linha
/// por ordem, com o motivo das recusadas.
class ServiceOrderBatchInvoiceDone extends ServiceOrderState {
  const ServiceOrderBatchInvoiceDone(this.report, {this.numbers = const {}});
  final BatchInvoiceReport report;

  /// D-F187: o NÚMERO que a tela mostra de cada OS do relatório (nunca a chave interna).
  final Map<int, int> numbers;

  @override
  List<Object?> get props => [report, numbers];
}

class ServiceOrderMonthlyRunDone extends ServiceOrderState {
  const ServiceOrderMonthlyRunDone(this.report);
  final MonthlyRunReport report;

  @override
  List<Object?> get props => [report];
}
