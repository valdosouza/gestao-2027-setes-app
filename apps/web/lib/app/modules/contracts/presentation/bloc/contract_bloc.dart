import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/contract_entity.dart';
import '../../domain/usecase/contract_delete.dart';
import '../../domain/usecase/contract_get.dart';
import '../../domain/usecase/contract_getlist.dart';
import '../../domain/usecase/contract_post.dart';
import '../../domain/usecase/contract_put.dart';

part 'contract_event.dart';
part 'contract_state.dart';

/// Orquestra os Contratos de serviço (Módulo Software House): lista ↔
/// formulário. A edição carrega o contrato COMPLETO (GET /:id) porque a
/// lista não traz itens; salvar envia os itens completos (a API
/// sincroniza por productId — DP3: mensalidade derivada, nunca enviada).
class ContractBloc extends Bloc<ContractEvent, ContractState> {
  ContractBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const ContractListState(loading: true)) {
    on<ContractListRequested>(_onListRequested);
    on<ContractNewPressed>((event, emit) {
      _editing = null;
      emit(const ContractFormState());
    });
    on<ContractEditPressed>(_onEditPressed);
    on<ContractBackToListPressed>((event, emit) => _reload(emit));
    on<ContractSaveRequested>(_onSaveRequested);
    on<ContractDeleteRequested>(_onDeleteRequested);
  }

  final ContractGetlist getlist;
  final ContractGet get;
  final ContractPost post;
  final ContractPut put;
  final ContractDelete delete;

  /// Lista completa (a API limita a 200 — o filtro da tela é LOCAL).
  List<ContractListItem> _all = const [];
  String _filter = '';

  /// Contrato aberto no form (null = novo) — preserva o editing nos
  /// re-emits de saving/falha.
  ContractFull? _editing;

  List<ContractListItem> get _filtered {
    if (_filter.isEmpty) return _all;
    final lower = _filter.toLowerCase();
    return _all
        .where((c) => (c.customerName ?? '').toLowerCase().contains(lower))
        .toList();
  }

  Future<void> _onListRequested(
      ContractListRequested event, Emitter<ContractState> emit) async {
    _filter = event.filter;
    if (event.refresh || _all.isEmpty) {
      await _reload(emit);
    } else {
      emit(ContractListState(items: _filtered));
    }
  }

  Future<void> _reload(Emitter<ContractState> emit) async {
    emit(const ContractListState(loading: true));
    final result = await getlist();
    result.fold(
      (failure) {
        emit(ContractActionFailure(failure.message));
        emit(const ContractListState());
      },
      (items) {
        _all = items;
        emit(ContractListState(items: _filtered));
      },
    );
  }

  Future<void> _onEditPressed(
      ContractEditPressed event, Emitter<ContractState> emit) async {
    emit(const ContractListState(loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(ContractActionFailure(failure.message));
        emit(ContractListState(items: _filtered));
      },
      (full) async {
        _editing = full;
        emit(ContractFormState(editing: full));
      },
    );
  }

  Future<void> _onSaveRequested(
      ContractSaveRequested event, Emitter<ContractState> emit) async {
    emit(ContractFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(ContractActionFailure(failure.message));
        // Mesmo editing → mesma ValueKey na página: o form preserva o
        // que o usuário digitou.
        emit(ContractFormState(editing: _editing));
      },
      (_) async {
        emit(const ContractActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      ContractDeleteRequested event, Emitter<ContractState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(ContractActionFailure(failure.message)),
      (_) async {
        emit(const ContractActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
