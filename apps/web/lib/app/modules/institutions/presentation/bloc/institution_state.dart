part of 'institution_bloc.dart';

sealed class InstitutionBlocState extends Equatable {
  const InstitutionBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class InstitutionListState extends InstitutionBlocState {
  const InstitutionListState({this.items = const [], this.loading = false});
  final List<InstitutionListItem> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). O [draft] é o ObjectInstitution INTEIRO —
/// as abas editam fatias via InstitutionDraftChanged.
class InstitutionFormState extends InstitutionBlocState {
  const InstitutionFormState({
    required this.draft,
    required this.creating,
    this.saving = false,
  });

  final ObjectInstitution draft;
  final bool creating;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, saving];
}

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class InstitutionActionSuccess extends InstitutionBlocState {
  const InstitutionActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class InstitutionActionFailure extends InstitutionBlocState {
  const InstitutionActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
