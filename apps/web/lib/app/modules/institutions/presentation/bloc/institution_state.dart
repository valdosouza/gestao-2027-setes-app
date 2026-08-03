part of 'institution_bloc.dart';

sealed class InstitutionBlocState extends Equatable {
  const InstitutionBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class InstitutionListState extends InstitutionBlocState {
  const InstitutionListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<InstitutionListItem> items;
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

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class InstitutionActionSuccess extends InstitutionBlocState {
  const InstitutionActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo da aba certa.
class InstitutionActionFailure extends InstitutionBlocState {
  const InstitutionActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
