part of 'salesman_bloc.dart';

sealed class SalesmanEvent extends Equatable {
  const SalesmanEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a pesquisa (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class SalesmanListRequested extends SalesmanEvent {
  const SalesmanListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Promoção (D1): o usuário escolheu um COLABORADOR no lookup — abre o
/// form de criação com a identificação readonly ([collaboratorName]) e os
/// campos do papel nos defaults (active='S', flex 0).
class SalesmanPromotePressed extends SalesmanEvent {
  const SalesmanPromotePressed(this.collaboratorId, this.collaboratorName);
  final int collaboratorId;
  final String collaboratorName;

  @override
  List<Object?> get props => [collaboratorId, collaboratorName];
}

/// Abre a edição: o bloc busca o papel + identificação via GET :id. Também
/// usado pelo dialog do 409 de papel duplicado (abrir o registro existente).
class SalesmanEditPressed extends SalesmanEvent {
  const SalesmanEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// A página editou uma fatia do draft (checkboxes fora dos values da
/// fábrica — o estado vive no bloc).
class SalesmanDraftChanged extends SalesmanEvent {
  const SalesmanDraftChanged(this.draft);
  final ObjectSalesman draft;

  @override
  List<Object?> get props => [draft];
}

class SalesmanBackToListPressed extends SalesmanEvent {
  const SalesmanBackToListPressed();
}

class SalesmanSaveRequested extends SalesmanEvent {
  const SalesmanSaveRequested({required this.draft, required this.creating});
  final ObjectSalesman draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class SalesmanDeleteRequested extends SalesmanEvent {
  const SalesmanDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
