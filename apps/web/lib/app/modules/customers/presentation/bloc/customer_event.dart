part of 'customer_bloc.dart';

sealed class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class CustomerListRequested extends CustomerEvent {
  const CustomerListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class CustomerNewPressed extends CustomerEvent {
  const CustomerNewPressed({this.personType, this.consumer});

  /// Pré-seleções do cadastro novo vindas do Framework de Configurações
  /// (piloto, decisões 10 e 14): default_person_type ('F'/'J') e
  /// default_customer_kind traduzido para o campo consumer ('S'/'N').
  /// null = padrão do código.
  final String? personType;
  final String? consumer;

  @override
  List<Object?> get props => [personType, consumer];
}

/// Abre a edição: o bloc busca o objeto COMPLETO via GET :id. Também usado
/// pelo dialog do 409 de papel duplicado (abrir o registro existente —
/// Fase 3, decisão 2).
class CustomerEditPressed extends CustomerEvent {
  const CustomerEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Uma aba editou uma fatia do draft (skill cadastro-entidade-fiscal.md).
class CustomerDraftChanged extends CustomerEvent {
  const CustomerDraftChanged(this.draft);
  final ObjectCustomer draft;

  @override
  List<Object?> get props => [draft];
}

/// Volta do formulário para a pesquisa SEM salvar.
class CustomerBackToListPressed extends CustomerEvent {
  const CustomerBackToListPressed();
}

/// Salvar = 1 evento com o objeto completo (cascade na API).
class CustomerSaveRequested extends CustomerEvent {
  const CustomerSaveRequested({required this.draft, required this.creating});
  final ObjectCustomer draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class CustomerDeleteRequested extends CustomerEvent {
  const CustomerDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
