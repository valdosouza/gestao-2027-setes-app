import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/country_entity.dart';
import '../../domain/usecase/country_delete.dart';
import '../../domain/usecase/country_getlist.dart';
import '../../domain/usecase/country_post.dart';
import '../../domain/usecase/country_put.dart';

part 'country_event.dart';
part 'country_state.dart';

/// Orquestra o CRUD de País: alterna pesquisa ↔ formulário e executa as
/// operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register* é
/// apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, piloto Onda A).
class CountryBloc extends Bloc<CountryEvent, CountryState> {
  CountryBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CountryListState(loading: true)) {
    on<CountryListRequested>(_onListRequested);
    on<CountryNewPressed>((event, emit) => emit(const CountryFormState()));
    on<CountryEditPressed>(
        (event, emit) => emit(CountryFormState(editing: event.country)));
    on<CountryBackToListPressed>((event, emit) => _reload(emit));
    on<CountrySaveRequested>(_onSaveRequested);
    on<CountryDeleteRequested>(_onDeleteRequested);
  }

  final CountryGetlist getlist;
  final CountryPost post;
  final CountryPut put;
  final CountryDelete delete;

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      CountryListRequested event, Emitter<CountryState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CountryState> emit) async {
    emit(const CountryListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(CountryActionFailure(failure));
        emit(const CountryListState());
      },
      (items) => emit(CountryListState(items: items)),
    );
  }

  Future<void> _onSaveRequested(
      CountrySaveRequested event, Emitter<CountryState> emit) async {
    emit(CountryFormState(
        editing: event.creating ? null : event.country, saving: true));
    final result = event.creating
        ? await post(event.country)
        : await put(event.country);
    await result.fold(
      (failure) async {
        emit(CountryActionFailure(failure));
        emit(CountryFormState(
            editing: event.creating ? null : event.country));
      },
      (_) async {
        emit(const CountryActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      CountryDeleteRequested event, Emitter<CountryState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CountryActionFailure(failure)),
      (_) async {
        emit(const CountryActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
