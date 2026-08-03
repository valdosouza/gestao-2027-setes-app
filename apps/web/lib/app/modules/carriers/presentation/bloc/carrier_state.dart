part of 'carrier_bloc.dart';

sealed class CarrierBlocState extends Equatable {
  const CarrierBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class CarrierListState extends CarrierBlocState {
  const CarrierListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<CarrierListItem> items;
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

/// Modo formulário (buildável). O [draft] é o ObjectCarrier INTEIRO — as
/// abas editam fatias via CarrierDraftChanged.
class CarrierFormState extends CarrierBlocState {
  const CarrierFormState({
    required this.draft,
    required this.creating,
    this.saving = false,
  });

  final ObjectCarrier draft;
  final bool creating;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CarrierActionSuccess extends CarrierBlocState {
  const CarrierActionSuccess(this.messageKey);

  /// Chave i18n — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo da aba certa.
class CarrierActionFailure extends CarrierBlocState {
  const CarrierActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Efeito one-shot do 409 de papel duplicado: a entity já é transportadora
/// desta institution — a página oferece abrir [existingId] em edição.
class CarrierDuplicateRole extends CarrierBlocState {
  const CarrierDuplicateRole(this.existingId);
  final int existingId;

  @override
  List<Object?> get props => [existingId];
}
