import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/payment_type_entity.dart';
import '../../domain/usecase/payment_type_delete.dart';
import '../../domain/usecase/payment_type_getlist.dart';
import '../../domain/usecase/payment_type_post.dart';
import '../../domain/usecase/payment_type_put.dart';

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
    on<PaymentTypeNewPressed>(
        (event, emit) => emit(const PaymentTypeFormState()));
    on<PaymentTypeEditPressed>(
        (event, emit) => emit(PaymentTypeFormState(editing: event.paymentType)));
    on<PaymentTypeBackToListPressed>((event, emit) => _reload(emit));
    on<PaymentTypeSaveRequested>(_onSaveRequested);
    on<PaymentTypeDeleteRequested>(_onDeleteRequested);
  }

  final PaymentTypeGetlist getlist;
  final PaymentTypePost post;
  final PaymentTypePut put;
  final PaymentTypeDelete delete;

  /// Lista completa (a API não filtra a lista de vinculadas — o filtro da
  /// tela é LOCAL, a lista é pequena).
  List<LinkedPaymentType> _all = const [];
  String _filter = '';

  Future<void> _onListRequested(
      PaymentTypeListRequested event, Emitter<PaymentTypeState> emit) async {
    _filter = event.filter;
    if (event.refresh || _all.isEmpty) {
      await _reload(emit);
    } else {
      emit(PaymentTypeListState(items: _filtered));
    }
  }

  List<LinkedPaymentType> get _filtered {
    if (_filter.isEmpty) return _all;
    final lower = _filter.toLowerCase();
    return _all
        .where((p) => (p.description ?? '').toLowerCase().contains(lower))
        .toList();
  }

  Future<void> _reload(Emitter<PaymentTypeState> emit) async {
    emit(const PaymentTypeListState(loading: true));
    final result = await getlist();
    result.fold(
      (failure) {
        emit(PaymentTypeActionFailure(failure));
        emit(const PaymentTypeListState());
      },
      (items) {
        _all = items;
        emit(PaymentTypeListState(items: _filtered));
      },
    );
  }

  Future<void> _onSaveRequested(
      PaymentTypeSaveRequested event, Emitter<PaymentTypeState> emit) async {
    final editing = event.editingId != null;
    emit(PaymentTypeFormState(
        editing: editing
            ? _all.firstWhere((p) => p.id == event.editingId,
                orElse: () => LinkedPaymentType(id: event.editingId!))
            : null,
        saving: true));

    if (editing) {
      final result = await put(event.editingId!,
          attrs: event.attrs, idNfce: event.idNfce);
      await result.fold(
        (failure) async {
          emit(PaymentTypeActionFailure(failure));
          emit(PaymentTypeFormState(
              editing: _all.firstWhere((p) => p.id == event.editingId,
                  orElse: () => LinkedPaymentType(id: event.editingId!))));
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
