part of 'service_list_bloc.dart';

sealed class ServiceListEvent extends Equatable {
  const ServiceListEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class ServiceListListRequested extends ServiceListEvent {
  const ServiceListListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class ServiceListNewPressed extends ServiceListEvent {
  const ServiceListNewPressed();
}

class ServiceListEditPressed extends ServiceListEvent {
  const ServiceListEditPressed(this.item);
  final ServiceListEntity item;

  @override
  List<Object?> get props => [item];
}

/// Volta do formulário para a pesquisa SEM salvar.
class ServiceListBackToListPressed extends ServiceListEvent {
  const ServiceListBackToListPressed();
}

class ServiceListSaveRequested extends ServiceListEvent {
  const ServiceListSaveRequested({required this.item, required this.creating});
  final ServiceListEntity item;
  final bool creating;

  @override
  List<Object?> get props => [item, creating];
}

class ServiceListDeleteRequested extends ServiceListEvent {
  const ServiceListDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
