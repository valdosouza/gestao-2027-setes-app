part of 'state_bloc.dart';

sealed class StateEvent extends Equatable {
  const StateEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class StateListRequested extends StateEvent {
  const StateListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class StateNewPressed extends StateEvent {
  const StateNewPressed();
}

class StateEditPressed extends StateEvent {
  const StateEditPressed(this.state);
  final StateEntity state;

  @override
  List<Object?> get props => [state];
}

/// Volta do formulário para a pesquisa SEM salvar.
class StateBackToListPressed extends StateEvent {
  const StateBackToListPressed();
}

class StateSaveRequested extends StateEvent {
  const StateSaveRequested({required this.state, required this.creating});
  final StateEntity state;
  final bool creating;

  @override
  List<Object?> get props => [state, creating];
}

class StateDeleteRequested extends StateEvent {
  const StateDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
