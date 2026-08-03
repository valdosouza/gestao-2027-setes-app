import 'package:core/core.dart';
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

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  /// D7: o filtro por nome do cliente é REMOTO (?filter=) — o cache local
  /// `_all/_filtered` foi aposentado.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Contrato aberto no form (null = novo) — preserva o editing nos
  /// re-emits de saving/falha.
  ContractFull? _editing;

  Future<void> _onListRequested(
      ContractListRequested event, Emitter<ContractState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ContractState> emit) async {
    emit(const ContractListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ContractActionFailure(failure));
        emit(const ContractListState());
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
        emit(ContractListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<ContractListItem> get _currentItems {
    final current = state;
    return current is ContractListState ? current.items : const [];
  }

  Future<void> _onEditPressed(
      ContractEditPressed event, Emitter<ContractState> emit) async {
    emit(ContractListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(ContractActionFailure(failure));
        emit(ContractListState(items: _currentItems));
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
        emit(ContractActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
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
      (failure) async => emit(ContractActionFailure(failure)),
      (_) async {
        emit(const ContractActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
