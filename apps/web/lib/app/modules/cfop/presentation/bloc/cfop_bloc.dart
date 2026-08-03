import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/cfop_entity.dart';
import '../../domain/usecase/cfop_delete.dart';
import '../../domain/usecase/cfop_getlist.dart';
import '../../domain/usecase/cfop_post.dart';
import '../../domain/usecase/cfop_put.dart';

part 'cfop_event.dart';
part 'cfop_state.dart';

/// Orquestra o CRUD de CFOP: alterna pesquisa ↔ formulário e executa as
/// operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register* é
/// apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, Onda B).
class CfopBloc extends Bloc<CfopEvent, CfopState> {
  CfopBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CfopListState(loading: true)) {
    on<CfopListRequested>(_onListRequested);
    on<CfopNewPressed>((event, emit) => emit(const CfopFormState()));
    on<CfopEditPressed>(
        (event, emit) => emit(CfopFormState(editing: event.cfop)));
    on<CfopBackToListPressed>((event, emit) => _reload(emit));
    on<CfopSaveRequested>(_onSaveRequested);
    on<CfopDeleteRequested>(_onDeleteRequested);
  }

  final CfopGetlist getlist;
  final CfopPost post;
  final CfopPut put;
  final CfopDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      CfopListRequested event, Emitter<CfopState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CfopState> emit) async {
    emit(const CfopListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(CfopActionFailure(failure));
        emit(const CfopListState());
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
        emit(CfopListState(
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
      CfopSaveRequested event, Emitter<CfopState> emit) async {
    emit(CfopFormState(
        editing: event.creating ? null : event.cfop, saving: true));
    final result =
        event.creating ? await post(event.cfop) : await put(event.cfop);
    await result.fold(
      (failure) async {
        emit(CfopActionFailure(failure));
        emit(CfopFormState(editing: event.creating ? null : event.cfop));
      },
      (_) async {
        emit(const CfopActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      CfopDeleteRequested event, Emitter<CfopState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CfopActionFailure(failure)),
      (_) async {
        emit(const CfopActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
