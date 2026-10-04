import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/payment_type_entity.dart';
import '../../domain/usecase/payment_type_delete.dart';
import '../../domain/usecase/payment_type_getlist.dart';
import '../../domain/usecase/payment_type_post.dart';
import '../../domain/usecase/payment_type_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'payment_type_event.dart';
part 'payment_type_state.dart';

/// Orquestra as Formas de Pagamento (workflow do Valdo, 2026-07-18):
/// lista das formas VINCULADAS ↔ formulário. Criar = vincular do catálogo
/// central (lookup) OU criar/reusar pela descrição — reused=true vira
/// SnackBar informativo (a forma já existia e foi apenas vinculada);
/// editar = só o vínculo (PaymentTypeLinkAttrs); excluir = desvincular.
class PaymentTypeBloc extends Bloc<PaymentTypeEvent, PaymentTypeState> {
  PaymentTypeBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const PaymentTypeListState(loading: true)) {
    on<PaymentTypeListRequested>(_onListRequested);
    on<PaymentTypeNewPressed>((event, emit) {
      _editing = null;
      emit(const PaymentTypeFormState());
    });
    on<PaymentTypeEditPressed>((event, emit) {
      _editing = event.paymentType;
      emit(PaymentTypeFormState(editing: event.paymentType));
    });
    on<PaymentTypeBackToListPressed>((event, emit) => _reload(emit));
    on<PaymentTypeSaveRequested>(_onSaveRequested);
    on<PaymentTypeDeleteRequested>(_onDeleteRequested);
  }

  final PaymentTypeGetlist getlist;
  final PaymentTypePost post;
  final PaymentTypePut put;
  final PaymentTypeDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  /// D7: o filtro por descrição é REMOTO (?filter=) — o cache local
  /// `_all/_filtered` foi aposentado.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  /// Vínculo aberto no form (null = novo) — preserva o editing nos
  /// re-emits de saving/falha.
  LinkedPaymentType? _editing;

  Future<void> _onListRequested(
      PaymentTypeListRequested event, Emitter<PaymentTypeState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<PaymentTypeState> emit) async {
    emit(PaymentTypeListState(
        loading: true, filter: _filter, criteria: _criteria));
    final result = await getlist(_filter,
        page: _page, pageSize: _pageSize, criteria: _criteria);
    await result.fold(
      (failure) async {
        // Q-BA16 (a): critério recusado pela API é DESCARTADO, o usuário é
        // avisado e a lista recarrega com os demais — nunca fica travada.
        final pruned = _criteria.withoutRejected(failure);
        if (pruned != null) {
          _criteria = pruned;
          emit(PaymentTypeActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(PaymentTypeActionFailure(failure));
        emit(PaymentTypeListState(filter: _filter, criteria: _criteria));
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API — D4/D5).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(PaymentTypeListState(
          items: paged.items,
          filter: _filter,
          criteria: _criteria,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  Future<void> _onSaveRequested(
      PaymentTypeSaveRequested event, Emitter<PaymentTypeState> emit) async {
    final editing = event.editingId != null;
    // O vínculo aberto fica em _editing (setado no EditPressed) — o cache
    // _all não existe mais (filtro remoto, D7).
    final current = editing
        ? (_editing ?? LinkedPaymentType(id: event.editingId!))
        : null;
    emit(PaymentTypeFormState(editing: current, saving: true));

    if (editing) {
      final result = await put(event.editingId!,
          attrs: event.attrs, idNfce: event.idNfce);
      await result.fold(
        (failure) async {
          emit(PaymentTypeActionFailure(failure));
          // Mesmo editing → o form continua montado: preserva o que o
          // usuário digitou e permite ancorar o fields[] no campo.
          emit(PaymentTypeFormState(editing: current));
        },
        (_) async {
          emit(const PaymentTypeActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
      return;
    }

    final result = await post(
      catalogId: event.catalogId,
      description: event.description,
      idNfce: event.idNfce,
      attrs: event.attrs,
    );
    await result.fold(
      (failure) async {
        emit(PaymentTypeActionFailure(failure));
        emit(const PaymentTypeFormState());
      },
      (postResult) async {
        // reused = a forma já existia no catálogo (foi apenas vinculada)
        emit(PaymentTypeActionSuccess(postResult.reused
            ? 'forms.paymentType.reused'
            : 'register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      PaymentTypeDeleteRequested event, Emitter<PaymentTypeState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(PaymentTypeActionFailure(failure)),
      (_) async {
        emit(const PaymentTypeActionSuccess('forms.paymentType.unlinked'));
        await _reload(emit);
      },
    );
  }
}
