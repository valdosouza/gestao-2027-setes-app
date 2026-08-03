part of 'collaborator_bloc.dart';

sealed class CollaboratorEvent extends Equatable {
  const CollaboratorEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a pesquisa (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class CollaboratorListRequested extends CollaboratorEvent {
  const CollaboratorListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class CollaboratorNewPressed extends CollaboratorEvent {
  const CollaboratorNewPressed();
}

/// Abre a edição: o bloc busca o objeto COMPLETO via GET :id. Também usado
/// pelo dialog do 409 de papel duplicado (abrir o registro existente).
class CollaboratorEditPressed extends CollaboratorEvent {
  const CollaboratorEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Uma aba editou uma fatia do draft.
class CollaboratorDraftChanged extends CollaboratorEvent {
  const CollaboratorDraftChanged(this.draft);
  final ObjectCollaborator draft;

  @override
  List<Object?> get props => [draft];
}

class CollaboratorBackToListPressed extends CollaboratorEvent {
  const CollaboratorBackToListPressed();
}

class CollaboratorSaveRequested extends CollaboratorEvent {
  const CollaboratorSaveRequested({required this.draft, required this.creating});
  final ObjectCollaborator draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class CollaboratorDeleteRequested extends CollaboratorEvent {
  const CollaboratorDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
