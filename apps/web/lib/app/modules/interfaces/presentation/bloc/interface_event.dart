part of 'interface_bloc.dart';

sealed class InterfaceEvent extends Equatable {
  const InterfaceEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class InterfaceListRequested extends InterfaceEvent {
  const InterfaceListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
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
