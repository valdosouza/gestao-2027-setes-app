part of 'collaborator_bloc.dart';

sealed class CollaboratorBlocState extends Equatable {
  const CollaboratorBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class CollaboratorListState extends CollaboratorBlocState {
  const CollaboratorListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<CollaboratorListItem> items;
  final bool loading;

  /// Filtro APLICADO (o mesmo usado na recarga pós-salvar/excluir).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, filter, page, pageSize, total];
}

/// Modo formulário (buildável). O [draft] é o ObjectCollaborator INTEIRO —
/// as abas editam fatias via CollaboratorDraftChanged.
class CollaboratorFormState extends CollaboratorBlocState {
  const CollaboratorFormState({
    required this.draft,
    required this.creating,
    this.saving = false,
  });

  final ObjectCollaborator draft;
  final bool creating;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CollaboratorActionSuccess extends CollaboratorBlocState {
  const CollaboratorActionSuccess(this.messageKey);

  /// Chave i18n — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo da aba certa.
class CollaboratorActionFailure extends CollaboratorBlocState {
  const CollaboratorActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Efeito one-shot do 409 de papel duplicado: a entity já é colaborador
/// desta institution — a página oferece abrir [existingId] em edição.
class CollaboratorDuplicateRole extends CollaboratorBlocState {
  const CollaboratorDuplicateRole(this.existingId);
  final int existingId;

  @override
  List<Object?> get props => [existingId];
}
