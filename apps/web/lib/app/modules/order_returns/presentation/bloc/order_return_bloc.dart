import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/order_return_entity.dart';
import '../../domain/usecase/order_return_billing_invoice.dart';
import '../../domain/usecase/order_return_billing_validate.dart';
import '../../domain/usecase/order_return_delete.dart';
import '../../domain/usecase/order_return_get.dart';
import '../../domain/usecase/order_return_getlist.dart';
import '../../domain/usecase/order_return_item_delete.dart';
import '../../domain/usecase/order_return_item_quantity_put.dart';
import '../../domain/usecase/order_return_post.dart';

part 'order_return_event.dart';
part 'order_return_state.dart';

/// Orquestra a Devolução de Mercadoria — TELA DE PROCESSO (molde orders):
/// lista em abas Abertas × Faturadas ↔ detalhe da devolução. A devolução
/// NASCE no módulo orders (ação "Devolver" no pedido faturado) com itens
/// pré-carregados pela API; aqui o usuário só edita quantidade (teto
/// maxQuantity), remove item, cancela ou fatura. Toda operação chama a API
/// e RECARREGA — total e status vivem no servidor. Faturamento é duas
/// chamadas (validate → invoice) ao módulo billing com adjustment =
/// { cfopId }, direto pela API (sem módulo billing próprio no app).
/// Falhas carregam o [Failure] INTEIRO no one-shot (Framework de
/// Mensagens): a página entrega à PONTE, que deriva o canal.
class OrderReturnBloc extends Bloc<OrderReturnEvent, OrderReturnState> {
  OrderReturnBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.delete,
    required this.itemQuantityPut,
    required this.itemDelete,
    required this.billingValidate,
    required this.billingInvoice,
  }) : super(const OrderReturnListState(loading: true)) {
    on<OrderReturnListRequested>(_onListRequested);
    on<OrderReturnOpenRequested>(_onOpenRequested);
    on<OrderReturnViewRequested>(_onViewRequested);
    on<OrderReturnBackToListPressed>((event, emit) => _reloadList(emit));
    on<OrderReturnCancelRequested>(_onCancelRequested);
    on<OrderReturnItemQuantityRequested>(_onItemQuantityRequested);
    on<OrderReturnItemRemoveRequested>(_onItemRemoveRequested);
    on<OrderReturnBillingValidateRequested>(_onBillingValidateRequested);
    on<OrderReturnBillingInvoiceRequested>(_onBillingInvoiceRequested);
  }

  final OrderReturnGetlist getlist;
  final OrderReturnGet get;
  final OrderReturnPost post;
  final OrderReturnDelete delete;
  final OrderReturnItemQuantityPut itemQuantityPut;
  final OrderReturnItemDelete itemDelete;
  final OrderReturnBillingValidate billingValidate;
  final OrderReturnBillingInvoiceUsecase billingInvoice;

  /// Aba ativa ('A' abertas | 'F' faturadas) e filtro atual da lista.
  String _status = 'A';
  String _filter = '';

  /// Última página/tamanho aplicados — recarga após operação devolve o
  /// usuário exatamente onde estava.
  int _page = 1;
  int? _pageSize;

  /// Devolução aberta no detalhe — preserva o conteúdo nos re-emits de
  /// saving/falha sem nova consulta.
  OrderReturnFull? _detail;

  Future<void> _reloadList(Emitter<OrderReturnState> emit) async {
    _detail = null;
    emit(OrderReturnListState(loading: true, status: _status));
    final result =
        await getlist(_status, _filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        emit(OrderReturnListState(status: _status));
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
        emit(OrderReturnListState(
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

  /// Recarrega o detalhe (o total é recalculado no servidor a cada
  /// operação de item).
  Future<void> _reloadDetail(int id, Emitter<OrderReturnState> emit) async {
    final result = await get(id);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        await _reloadList(emit);
      },
      (full) async {
        _detail = full;
        emit(OrderReturnDetailState(orderReturn: full));
      },
    );
  }

  Future<void> _onListRequested(
      OrderReturnListRequested event, Emitter<OrderReturnState> emit) async {
    _status = event.status ?? _status;
    _filter = event.filter ?? _filter;
    // Troca de aba/filtro SEMPRE volta à página 1 (default do evento); só
    // a navegação da barra manda outra página.
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reloadList(emit);
  }

  Future<void> _onOpenRequested(
      OrderReturnOpenRequested event, Emitter<OrderReturnState> emit) async {
    emit(OrderReturnListState(loading: true, status: _status));
    final result = await post(event.saleOrderId);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        await _reloadList(emit);
      },
      (id) async {
        emit(const OrderReturnActionSuccess('forms.orderReturn.opened'));
        await _reloadDetail(id, emit);
      },
    );
  }

  Future<void> _onViewRequested(
      OrderReturnViewRequested event, Emitter<OrderReturnState> emit) async {
    emit(OrderReturnListState(loading: true, status: _status));
    await _reloadDetail(event.id, emit);
  }

  Future<void> _onCancelRequested(
      OrderReturnCancelRequested event, Emitter<OrderReturnState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(OrderReturnDetailState(orderReturn: detail, saving: true));
    }
    final result = await delete(event.id);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        if (detail != null) emit(OrderReturnDetailState(orderReturn: detail));
      },
      (_) async {
        emit(const OrderReturnActionSuccess('forms.orderReturn.canceled'));
        await _reloadList(emit);
      },
    );
  }

  Future<void> _onItemQuantityRequested(OrderReturnItemQuantityRequested event,
      Emitter<OrderReturnState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(OrderReturnDetailState(orderReturn: detail, saving: true));
    }
    final result =
        await itemQuantityPut(event.returnId, event.itemId, event.quantity);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        if (detail != null) emit(OrderReturnDetailState(orderReturn: detail));
      },
      (_) async {
        emit(const OrderReturnActionSuccess('register.saved'));
        await _reloadDetail(event.returnId, emit);
      },
    );
  }

  Future<void> _onItemRemoveRequested(OrderReturnItemRemoveRequested event,
      Emitter<OrderReturnState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(OrderReturnDetailState(orderReturn: detail, saving: true));
    }
    final result = await itemDelete(event.returnId, event.itemId);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        if (detail != null) emit(OrderReturnDetailState(orderReturn: detail));
      },
      (_) async {
        emit(const OrderReturnActionSuccess('register.deleted'));
        await _reloadDetail(event.returnId, emit);
      },
    );
  }

  Future<void> _onBillingValidateRequested(
      OrderReturnBillingValidateRequested event,
      Emitter<OrderReturnState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(OrderReturnDetailState(orderReturn: detail, saving: true));
    }
    final result = await billingValidate(event.returnId, event.cfopId);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        // R4 do gate socrático 2026-08-24: falha pode vir de corrida com
        // devolução irmã — o detalhe (maxQuantity) precisa vir FRESCO da
        // API, nunca do snapshot local.
        await _reloadDetail(event.returnId, emit);
      },
      (validation) async {
        emit(OrderReturnBillingValidated(validation, event.cfopId));
        if (detail != null) emit(OrderReturnDetailState(orderReturn: detail));
      },
    );
  }

  Future<void> _onBillingInvoiceRequested(
      OrderReturnBillingInvoiceRequested event,
      Emitter<OrderReturnState> emit) async {
    final detail = _detail;
    if (detail != null) {
      emit(OrderReturnDetailState(orderReturn: detail, saving: true));
    }
    final result = await billingInvoice(event.returnId, event.cfopId);
    await result.fold(
      (failure) async {
        emit(OrderReturnActionFailure(failure));
        // R4: idem — o 422 RETURN_INVALID de corrida chega SÓ aqui; o
        // usuário ajusta contra tetos atualizados, não defasados.
        await _reloadDetail(event.returnId, emit);
      },
      (invoiceResult) async {
        emit(OrderReturnBillingInvoiced(invoiceResult));
        // Fluxo do processo: a devolução faturada aparece na aba Faturadas
        // — troca de aba SEMPRE volta à página 1.
        _status = 'F';
        _page = 1;
        await _reloadList(emit);
      },
    );
  }
}
