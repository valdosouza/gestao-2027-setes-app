import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/client_institution_entity.dart';
import '../../domain/usecase/institution_interfaces_getlist.dart';

part 'institution_interfaces_event.dart';
part 'institution_interfaces_state.dart';

/// Orquestra a tela "Interfaces dos clientes" (D-PV11): lista paginada de
/// estabelecimentos ↔ as interfaces do estabelecimento aberto (a aba
/// compartilhada carrega e grava sozinha pela fonte do módulo).
class InstitutionInterfacesBloc extends Bloc<InstitutionInterfacesEvent, InstitutionInterfacesState> {
  InstitutionInterfacesBloc({required this.getList}) : super(const InstitutionInterfacesListState(loading: true)) {
    on<InstitutionInterfacesListRequested>(_onListRequested);
    on<InstitutionInterfacesOpened>((event, emit) => emit(InstitutionInterfacesDetailState(event.client)));
    on<InstitutionInterfacesBackToList>((event, emit) => _reload(emit));
  }

  final InstitutionInterfacesGetlist getList;

  /// Últimos filtro/página/tamanho — a volta do detalhe devolve o usuário onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(InstitutionInterfacesListRequested event, Emitter<InstitutionInterfacesState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<InstitutionInterfacesState> emit) async {
    emit(InstitutionInterfacesListState(loading: true, filter: _filter));
    final result = await getList(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(InstitutionInterfacesActionFailure(failure));
        emit(InstitutionInterfacesListState(filter: _filter));
      },
      (paged) async {
        // Página esvaziou (filtro/clamp) → recua para a última existente.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(InstitutionInterfacesListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }
}
