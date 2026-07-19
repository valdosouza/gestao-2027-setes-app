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

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      CityListRequested event, Emitter<CityState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CityState> emit) async {
    emit(const CityListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(CityActionFailure(failure));
        emit(const CityListState());
      },
      (items) => emit(CityListState(items: items)),
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
