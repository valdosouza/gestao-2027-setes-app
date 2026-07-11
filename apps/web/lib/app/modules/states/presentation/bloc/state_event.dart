part of 'state_bloc.dart';

sealed class StateEvent extends Equatable {
  const StateEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
class StateListRequested extends StateEvent {
  const StateListRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
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
