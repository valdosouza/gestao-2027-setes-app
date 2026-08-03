import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/city_entity.dart';
import '../../domain/usecase/city_delete.dart';
import '../../domain/usecase/city_getlist.dart';
import '../../domain/usecase/city_post.dart';
import '../../domain/usecase/city_put.dart';

part 'city_event.dart';
part 'city_state.dart';

/// Orquestra o CRUD de Cidade: alterna pesquisa ↔ formulário e executa as
/// operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register* é
/// apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, Onda B).
class CityBloc extends Bloc<CityEvent, CityState> {
  CityBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CityListState(loading: true)) {
    on<CityListRequested>(_onListRequested);
    on<CityNewPressed>((event, emit) => emit(const CityFormState()));
    on<CityEditPressed>(
        (event, emit) => emit(CityFormState(editing: event.city)));
    on<CityBackToListPressed>((event, emit) => _reload(emit));
    on<CitySaveRequested>(_onSaveRequested);
    on<CityDeleteRequested>(_onDeleteRequested);
  }

  final CityGetlist getlist;
  final CityPost post;
  final CityPut put;
  final CityDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      CityListRequested event, Emitter<CityState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CityState> emit) async {
    emit(const CityListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(CityActionFailure(failure));
        emit(const CityListState());
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
        emit(CityListState(
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
      CitySaveRequested event, Emitter<CityState> emit) async {
    emit(CityFormState(
        editing: event.creating ? null : event.city, saving: true));
    final result =
        event.creating ? await post(event.city) : await put(event.city);
    await result.fold(
      (failure) async {
        emit(CityActionFailure(failure));
        emit(CityFormState(editing: event.creating ? null : event.city));
      },
      (_) async {
        emit(const CityActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      CityDeleteRequested event, Emitter<CityState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CityActionFailure(failure)),
      (_) async {
        emit(const CityActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
