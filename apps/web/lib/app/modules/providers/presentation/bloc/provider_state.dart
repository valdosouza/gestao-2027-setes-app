part of 'provider_bloc.dart';

sealed class ProviderBlocState extends Equatable {
  const ProviderBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class ProviderListState extends ProviderBlocState {
  const ProviderListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<ProviderListItem> items;
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

/// Modo formulário (buildável). O [draft] é o ObjectProvider INTEIRO — as
/// abas editam fatias via ProviderDraftChanged.
class ProviderFormState extends ProviderBlocState {
  const ProviderFormState({
    required this.draft,
    required this.creating,
    this.saving = false,
  });

  final ObjectProvider draft;
  final bool creating;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class ProviderActionSuccess extends ProviderBlocState {
  const ProviderActionSuccess(this.messageKey);

  /// Chave i18n — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo da aba certa.
class ProviderActionFailure extends ProviderBlocState {
  const ProviderActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Efeito one-shot do 409 de papel duplicado: a entity já é fornecedor
/// desta institution — a página oferece abrir [existingId] em edição.
class ProviderDuplicateRole extends ProviderBlocState {
  const ProviderDuplicateRole(this.existingId);
  final int existingId;

  @override
  List<Object?> get props => [existingId];
}
