import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/bank_entity.dart';
import '../../domain/usecase/bank_delete.dart';
import '../../domain/usecase/bank_getlist.dart';
import '../../domain/usecase/bank_post.dart';
import '../../domain/usecase/bank_put.dart';

part 'bank_event.dart';
part 'bank_state.dart';

/// Orquestra o CRUD de Banco: alterna pesquisa ↔ formulário e executa
/// as operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register*
/// é apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, Onda B).
class BankBloc extends Bloc<BankEvent, BankState> {
  BankBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const BankListState(loading: true)) {
    on<BankListRequested>(_onListRequested);
    on<BankNewPressed>((event, emit) => emit(const BankFormState()));
    on<BankEditPressed>(
        (event, emit) => emit(BankFormState(editing: event.bank)));
    on<BankBackToListPressed>((event, emit) => _reload(emit));
    on<BankSaveRequested>(_onSaveRequested);
    on<BankDeleteRequested>(_onDeleteRequested);
  }

  final BankGetlist getlist;
  final BankPost post;
  final BankPut put;
  final BankDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      BankListRequested event, Emitter<BankState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<BankState> emit) async {
    emit(const BankListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(BankActionFailure(failure));
        emit(const BankListState());
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
        emit(BankListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  Future<void> _onSaveRequested(
      BankSaveRequested event, Emitter<BankState> emit) async {
    emit(BankFormState(
        editing: event.creating ? null : event.bank, saving: true));
    final result = event.creating
        ? await post(event.bank)
        : await put(event.bank);
    await result.fold(
      (failure) async {
        emit(BankActionFailure(failure));
        emit(BankFormState(
            editing: event.creating ? null : event.bank));
      },
      (_) async {
        emit(const BankActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      BankDeleteRequested event, Emitter<BankState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(BankActionFailure(failure)),
      (_) async {
        emit(const BankActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
