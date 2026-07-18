part of 'collaborator_bloc.dart';

sealed class CollaboratorBlocState extends Equatable {
  const CollaboratorBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class CollaboratorListState extends CollaboratorBlocState {
  const CollaboratorListState({this.items = const [], this.loading = false});
  final List<CollaboratorListItem> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
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

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class CollaboratorActionSuccess extends CollaboratorBlocState {
  const CollaboratorActionSuccess(this.messageKey);

  /// Chave i18n — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class CollaboratorActionFailure extends CollaboratorBlocState {
  const CollaboratorActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Efeito one-shot do 409 de papel duplicado: a entity já é colaborador
/// desta institution — a página oferece abrir [existingId] em edição.
class CollaboratorDuplicateRole extends CollaboratorBlocState {
  const CollaboratorDuplicateRole(this.existingId);
  final int existingId;

  @override
  List<Object?> get props => [existingId];
}
