part of 'interface_bloc.dart';

sealed class InterfaceEvent extends Equatable {
  const InterfaceEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
class InterfaceListRequested extends InterfaceEvent {
  const InterfaceListRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class InterfaceNewPressed extends InterfaceEvent {
  const InterfaceNewPressed();
}

class InterfaceEditPressed extends InterfaceEvent {
  const InterfaceEditPressed(this.entity);
  final InterfaceEntity entity;

  @override
  List<Object?> get props => [entity];
}

/// Volta do formulário para a pesquisa SEM salvar.
class InterfaceBackToListPressed extends InterfaceEvent {
  const InterfaceBackToListPressed();
}

class InterfaceSaveRequested extends InterfaceEvent {
  const InterfaceSaveRequested({required this.entity, required this.creating});
  final InterfaceEntity entity;
  final bool creating;

  @override
  List<Object?> get props => [entity, creating];
}

class InterfaceDeleteRequested extends InterfaceEvent {
  const InterfaceDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
