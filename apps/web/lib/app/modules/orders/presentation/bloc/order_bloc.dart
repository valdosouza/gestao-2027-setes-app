import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/order_entity.dart';
import '../../domain/usecase/order_billing_invoice.dart';
import '../../domain/usecase/order_billing_validate.dart';
import '../../domain/usecase/order_delete.dart';
import '../../domain/usecase/order_get.dart';
import '../../domain/usecase/order_getlist.dart';
import '../../domain/usecase/order_item_delete.dart';
import '../../domain/usecase/order_item_save.dart';
import '../../domain/usecase/order_negotiation_get.dart';
import '../../domain/usecase/order_negotiation_save.dart';
import '../../domain/usecase/order_post.dart';
import '../../domain/usecase/order_return_open.dart';

part 'order_event.dart';
part 'order_state.dart';

/// Orquestra o Pedido de Venda/Conjugado — TELA DE PROCESSO (molde
/// service_orders): lista em abas Abertos × Faturados ↔ detalhe do
/// pedido. Toda operação (abrir, item, negociar, cancelar, faturar) chama
/// a API e RECARREGA — o totalizer, a base da negociação e o status vivem
/// no servidor. A NEGOCIAÇÃO (forma/prazo × parcelamento elaborado —
/// prompt_negociacao_pedido.md) é atributo do pedido: carregada junto com
/// o detalhe e recarregada a cada operação de item (a base muda).
/// Faturamento é duas chamadas (validate → invoice) ao módulo billing,
/// direto pela API (sem módulo billing próprio no app); entre as duas a
/// negociação é RELIDA para a página decidir se coleta cheques (D5).
/// Falhas carregam o [Failure] INTEIRO no one-shot (Framework de
/// Mensagens): a página entrega à PONTE, que deriva o canal.
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  OrderBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.delete,
    required this.itemSave,
    required this.itemDelete,
    required this.billingValidate,
    required this.billingInvoice,
    required this.returnOpen,
    required this.negotiationGet,
    required this.negotiationSave,
  }) : super(const OrderListState(loading: true)) {
    on<OrderListRequested>(_onListRequested);
    on<OrderOpenRequested>(_onOpenRequested);
    on<OrderViewRequested>(_onViewRequested);
    on<OrderBackToListPressed>((event, emit) => _reloadList(emit));
    on<OrderCancelRequested>(_onCancelRequested);
    on<OrderItemSaveRequested>(_onItemSaveRequested);
    on<OrderItemRemoveRequested>(_onItemRemoveRequested);
    on<OrderBillingValidateRequested>(_onBillingValidateRequested);
    on<OrderBillingInvoiceRequested>(_onBillingInvoiceRequested);
    on<OrderReturnRequested>(_onReturnRequested);
    on<OrderNegotiationRequested>(_onNegotiationRequested);
    on<OrderNegotiationSaveRequested>(_onNegotiationSaveRequested);
  }

  final OrderGetlist getlist;
  final OrderGet get;
  final OrderPost post;
  final OrderDelete delete;
  final OrderItemSave itemSave;
  final OrderItemDelete itemDelete;
  final OrderBillingValidate billingValidate;
  final OrderBillingInvoiceUsecase billingInvoice;
  final OrderReturnOpen returnOpen;
  final OrderNegotiationGet negotiationGet;
  final OrderNegotiationSave negotiationSave;

  /// Abertura de devolução em voo (guard de duplo-clique — R5 do gate).
  bool _returnOpening = false;

  /// Aba ativa ('A' abertos | 'F' faturados) e filtro atual da lista.
  String _status = 'A';
  String _filter = '';

  /// Última página/tamanho aplicados — recarga após operação devolve o
  /// usuário exatamente onde estava.
  int _page = 1;
  int? _pageSize;

  /// Pedido aberto no detalhe — preserva o conteúdo nos re-emits de
  /// saving/falha sem nova consulta.
  OrderFull? _detail;

  /// Negociação do pedido do detalhe (null = leitura falhou/ainda não
  /// lida) — acompanha o [_detail] em todo re-emit.
  OrderNegotiation? _negotiation;

  /// Re-emite o detalhe corrente (com a negociação cacheada); nada se não
  /// há detalhe aberto.
  void _emitDetail(Emitter<OrderState> emit, {bool saving = false}) {
    final detail = _detail;
    if (detail == null) return;
    emit(OrderDetailState(
        order: detail, negotiation: _negotiation, saving: saving));
  }

  Future<void> _reloadList(Emitter<OrderState> emit) async {
    _detail = null;
    _negotiation = null;
    emit(OrderListState(loading: true, status: _status));
    final result =
        await getlist(_status, _filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        emit(OrderListState(status: _status));
      },
      (paged) async {
        // Página esvaziou (ex.: faturamento tirou o último item da aba) →
        // recua para a última página existente em vez de lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reloadList(emit);
        }
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(OrderListState(
          items: paged.items,
          status: _status,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  /// Lê a negociação do pedido — falha vira one-shot (a seção mostra
  /// "recarregar") e devolve null; o detalhe segue utilizável.
  Future<OrderNegotiation?> _fetchNegotiation(
      int id, Emitter<OrderState> emit) async {
    final result = await negotiationGet(id);
    return result.fold(
      (failure) {
        emit(OrderActionFailure(failure));
        return null;
      },
      (negotiation) => negotiation,
    );
  }

  /// Recarrega o detalhe (o totalizer é recalculado no servidor a cada
  /// operação de item) E a negociação (a base do pedido muda junto).
  Future<void> _reloadDetail(int id, Emitter<OrderState> emit) async {
    final result = await get(id);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        await _reloadList(emit);
      },
      (full) async {
        _detail = full;
        _negotiation = await _fetchNegotiation(full.id, emit);
        _emitDetail(emit);
      },
    );
  }

  Future<void> _onListRequested(
      OrderListRequested event, Emitter<OrderState> emit) async {
    _status = event.status ?? _status;
    _filter = event.filter ?? _filter;
    // Troca de aba/filtro SEMPRE volta à página 1 (default do evento); só
    // a navegação da barra manda outra página.
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reloadList(emit);
  }

  Future<void> _onOpenRequested(
      OrderOpenRequested event, Emitter<OrderState> emit) async {
    emit(OrderListState(loading: true, status: _status));
    final result = await post(event.customerId, event.salesmanId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        await _reloadList(emit);
      },
      (id) async {
        emit(const OrderActionSuccess('forms.order.opened'));
        await _reloadDetail(id, emit);
      },
    );
  }

  Future<void> _onViewRequested(
      OrderViewRequested event, Emitter<OrderState> emit) async {
    emit(OrderListState(loading: true, status: _status));
    await _reloadDetail(event.id, emit);
  }

  Future<void> _onCancelRequested(
      OrderCancelRequested event, Emitter<OrderState> emit) async {
    _emitDetail(emit, saving: true);
    final result = await delete(event.id);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        _emitDetail(emit);
      },
      (_) async {
        emit(const OrderActionSuccess('forms.order.canceled'));
        await _reloadList(emit);
      },
    );
  }

  Future<void> _onItemSaveRequested(
      OrderItemSaveRequested event, Emitter<OrderState> emit) async {
    _emitDetail(emit, saving: true);
    final result = await itemSave(event.orderId, event.itemId, event.input);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        _emitDetail(emit);
      },
      (_) async {
        emit(const OrderActionSuccess('register.saved'));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  Future<void> _onItemRemoveRequested(
      OrderItemRemoveRequested event, Emitter<OrderState> emit) async {
    _emitDetail(emit, saving: true);
    final result = await itemDelete(event.orderId, event.itemId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        _emitDetail(emit);
      },
      (_) async {
        emit(const OrderActionSuccess('register.deleted'));
        await _reloadDetail(event.orderId, emit);
      },
    );
  }

  /// Validate → sem issues, RELÊ a negociação (nunca a grade velha) e
  /// entrega as duas coisas à página, que decide se coleta cheques (D5)
  /// antes do invoice. Com issues, só o resultado (dialog de pendências).
  Future<void> _onBillingValidateRequested(
      OrderBillingValidateRequested event, Emitter<OrderState> emit) async {
    _emitDetail(emit, saving: true);
    final result = await billingValidate(event.orderId);
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        _emitDetail(emit);
      },
      (validation) async {
        if (!validation.canInvoice) {
          emit(OrderBillingValidated(validation));
          _emitDetail(emit);
          return;
        }
        final negotiation = await _fetchNegotiation(event.orderId, emit);
        if (negotiation == null) {
          // Sem a negociação fresca não dá pra saber se há cheque — não
          // fatura (a falha já foi emitida).
          _emitDetail(emit);
          return;
        }
        _negotiation = negotiation;
        emit(OrderBillingValidated(validation, negotiation: negotiation));
        _emitDetail(emit);
      },
    );
  }

  Future<void> _onBillingInvoiceRequested(
      OrderBillingInvoiceRequested event, Emitter<OrderState> emit) async {
    _emitDetail(emit, saving: true);
    final result = await billingInvoice(event.orderId, checks: event.checks);
    await result.fold(
      (failure) async {
        // One-shot PRÓPRIO do invoice: leva os cheques enviados para a
        // página reabrir o dialog em CHECK_SUM_MISMATCH/CHECK_REQUIRED.
        emit(OrderBillingInvoiceFailure(failure, checks: event.checks));
        _emitDetail(emit);
      },
      (invoiceResult) async {
        emit(OrderBillingInvoiced(invoiceResult));
        // Fluxo do processo: o pedido faturado aparece na aba Faturados —
        // troca de aba SEMPRE volta à página 1.
        _status = 'F';
        _page = 1;
        await _reloadList(emit);
      },
    );
  }

  /// Ação "Devolver" do pedido FATURADO: abre a devolução na API e emite o
  /// one-shot [OrderReturnOpened] — quem navega para o módulo
  /// order_returns é a página (módulo nunca importa módulo).
  Future<void> _onReturnRequested(
      OrderReturnRequested event, Emitter<OrderState> emit) async {
    // R5 do gate socrático 2026-08-24: duplo-clique enfileira 2 eventos
    // antes do rebuild desabilitar o botão — o guard mata o segundo (duas
    // devoluções nasceriam com o saldo cheio; acidente ≠ irmã intencional).
    if (_returnOpening) return;
    _returnOpening = true;
    _emitDetail(emit, saving: true);
    final result = await returnOpen(event.orderId);
    _returnOpening = false;
    await result.fold(
      (failure) async {
        emit(OrderActionFailure(failure));
        _emitDetail(emit);
      },
      (returnId) async {
        emit(OrderReturnOpened(returnId));
        _emitDetail(emit);
      },
    );
  }

  /// "Recarregar negociação" explícito (a carga normal vem com o detalhe).
  Future<void> _onNegotiationRequested(
      OrderNegotiationRequested event, Emitter<OrderState> emit) async {
    if (_detail == null || _detail!.id != event.orderId) return;
    _emitDetail(emit, saving: true);
    final negotiation = await _fetchNegotiation(event.orderId, emit);
    if (negotiation != null) _negotiation = negotiation;
    _emitDetail(emit);
  }

  /// PUT da negociação — sucesso substitui a negociação cacheada pela
  /// RECOMPOSTA da API (mode/preview/base atualizados) e avisa por
  /// SnackBar; falha vai no one-shot próprio para a seção ancorar o campo.
  Future<void> _onNegotiationSaveRequested(
      OrderNegotiationSaveRequested event, Emitter<OrderState> emit) async {
    _emitDetail(emit, saving: true);
    final result = await negotiationSave(event.orderId, event.input);
    await result.fold(
      (failure) async {
        emit(OrderNegotiationFailure(failure));
        _emitDetail(emit);
      },
      (negotiation) async {
        _negotiation = negotiation;
        emit(OrderActionSuccess(event.input.isElaborated
            ? 'forms.order.negotiationSavedElaborated'
            : 'forms.order.negotiationSaved'));
        _emitDetail(emit);
      },
    );
  }
}
