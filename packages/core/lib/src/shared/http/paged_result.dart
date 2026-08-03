/// Página de resultado das listas de pesquisa (paginação D3 —
/// prompt_paginacao_telas_pesquisa.md): espelho do envelope
/// `{ ok, data, page, pageSize, total }` da setes-api. Substitui o
/// `List<T>` puro nas camadas dos módulos adaptados — datasource →
/// repository → usecase → state carregam a página INTEIRA (itens +
/// metadados), e a RegisterSearchPage monta a barra de paginação.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  /// Envelope paginado da API → página tipada ([itemFromJson] por item).
  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final data = json['data'] as List<dynamic>? ?? const [];
    return PagedResult(
      items: data
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? data.length,
      total: (json['total'] as num?)?.toInt() ?? data.length,
    );
  }

  const PagedResult.empty()
      : items = const [],
        page = 1,
        pageSize = 0,
        total = 0;

  final List<T> items;

  /// 1-based, como na API.
  final int page;
  final int pageSize;

  /// Total de registros com o MESMO filtro/escopo da listagem (D2).
  final int total;

  /// Total de páginas (mínimo 1 — lista vazia ainda mostra "1 de 1").
  int get pageCount =>
      total <= 0 || pageSize <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
}
