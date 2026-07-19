import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/bank_account_entity.dart';
import '../../domain/usecase/bank_account_delete.dart';
import '../../domain/usecase/bank_account_get.dart';
import '../../domain/usecase/bank_account_getlist.dart';
import '../../domain/usecase/bank_account_post.dart';
import '../../domain/usecase/bank_account_put.dart';

part 'bank_account_event.dart';
part 'bank_account_state.dart';

/// Orquestra as Contas Bancárias (Módulo Software House): lista ↔
/// formulário. A edição carrega a conta COMPLETA (GET /:id) porque a
/// lista não traz datas nem telefone; o filtro da tela é LOCAL (a API
/// limita a 200 — molde contracts).
class BankAccountBloc extends Bloc<BankAccountEvent, BankAccountState> {
  BankAccountBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const BankAccountListState(loading: true)) {
    on<BankAccountListRequested>(_onListRequested);
    on<BankAccountNewPressed>((event, emit) {
      _editing = null;
      emit(const BankAccountFormState());
    });
    on<BankAccountEditPressed>(_onEditPressed);
    on<BankAccountBackToListPressed>((event, emit) => _reload(emit));
    on<BankAccountSaveRequested>(_onSaveRequested);
    on<BankAccountDeleteRequested>(_onDeleteRequested);
  }

  final BankAccountGetlist getlist;
  final BankAccountGet get;
  final BankAccountPost post;
  final BankAccountPut put;
  final BankAccountDelete delete;

  /// Lista completa (a API limita a 200 — o filtro da tela é LOCAL).
  List<BankAccountListItem> _all = const [];
  String _filter = '';

  /// Conta aberta no form (null = nova) — preserva o editing nos
  /// re-emits de saving/falha.
  BankAccountFull? _editing;

  List<BankAccountListItem> get _filtered {
    if (_filter.isEmpty) return _all;
    final lower = _filter.toLowerCase();
    return _all
        .where((a) =>
            a.bankDisplay.toLowerCase().contains(lower) ||
            a.agencyDisplay.toLowerCase().contains(lower) ||
            a.numberDisplay.toLowerCase().contains(lower) ||
            (a.manager ?? '').toLowerCase().contains(lower))
        .toList();
  }

  Future<void> _onListRequested(
      BankAccountListRequested event, Emitter<BankAccountState> emit) async {
    _filter = event.filter;
    if (event.refresh || _all.isEmpty) {
      await _reload(emit);
    } else {
      emit(BankAccountListState(items: _filtered));
    }
  }

  Future<void> _reload(Emitter<BankAccountState> emit) async {
    emit(const BankAccountListState(loading: true));
    final result = await getlist();
    result.fold(
      (failure) {
        emit(BankAccountActionFailure(failure));
        emit(const BankAccountListState());
      },
      (items) {
        _all = items;
        emit(BankAccountListState(items: _filtered));
      },
    );
  }

  Future<void> _onEditPressed(
      BankAccountEditPressed event, Emitter<BankAccountState> emit) async {
    emit(const BankAccountListState(loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(BankAccountActionFailure(failure));
        emit(BankAccountListState(items: _filtered));
      },
      (full) async {
        _editing = full;
        emit(BankAccountFormState(editing: full));
      },
    );
  }

  Future<void> _onSaveRequested(
      BankAccountSaveRequested event, Emitter<BankAccountState> emit) async {
    emit(BankAccountFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(BankAccountActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(BankAccountFormState(editing: _editing));
      },
      (_) async {
        emit(const BankAccountActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      BankAccountDeleteRequested event, Emitter<BankAccountState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(BankAccountActionFailure(failure)),
      (_) async {
        emit(const BankAccountActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
