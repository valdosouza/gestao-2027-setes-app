part of 'salesman_bloc.dart';

sealed class SalesmanBlocState extends Equatable {
  const SalesmanBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class SalesmanListState extends SalesmanBlocState {
  const SalesmanListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<SalesmanListItem> items;
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

/// Modo formulário (buildável). O [draft] carrega a identificação readonly
/// do colaborador + os campos do papel; a página edita os campos via
/// SalesmanDraftChanged/values do onSave.
class SalesmanFormState extends SalesmanBlocState {
  const SalesmanFormState({
    required this.draft,
    required this.creating,
    this.saving = false,
  });

  final ObjectSalesman draft;
  final bool creating;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class SalesmanActionSuccess extends SalesmanBlocState {
  const SalesmanActionSuccess(this.messageKey);

  /// Chave i18n — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo.
class SalesmanActionFailure extends SalesmanBlocState {
  const SalesmanActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Efeito one-shot do 409 de papel duplicado: o colaborador já é vendedor
/// desta institution — a página oferece abrir [existingId] em edição.
class SalesmanDuplicateRole extends SalesmanBlocState {
  const SalesmanDuplicateRole(this.existingId);
  final int existingId;

  @override
  List<Object?> get props => [existingId];
}
