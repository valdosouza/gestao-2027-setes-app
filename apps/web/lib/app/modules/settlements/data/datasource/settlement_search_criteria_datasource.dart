import '../../../../shared/search/search_criteria_datasource.dart';

// Pesquisa avançada da Baixa de Títulos (D-BA2, Bloco B): a tela tem DUAS
// listas paginadas, cada uma com o SEU catálogo e os SEUS lookups — a peça
// compartilhada é amarrada a UM `basePath` e recusa lookup fora dele. O
// Modular resolve por TIPO (dois binds do mesmo tipo não servem), então
// cada lista ganha o seu tipo, com o `basePath` FIXO no construtor.
// O extrato (aba Movimento) não pagina e não tem pesquisa avançada.

/// Títulos (aba Em aberto): `GET /api/settlements/bills/search-criteria`;
/// lookups `/api/settlements/bills/entity-lookup` e
/// `/api/settlements/bills/payment-types-lookup`.
class BillSearchCriteriaDatasource extends SearchCriteriaDatasourceImpl {
  const BillSearchCriteriaDatasource({required super.client})
      : super(basePath: '/api/settlements/bills');
}

/// Baixas (aba Baixados): `GET /api/settlements/settled/search-criteria`
/// (catálogo sem lookups).
class SettledSearchCriteriaDatasource extends SearchCriteriaDatasourceImpl {
  const SettledSearchCriteriaDatasource({required super.client})
      : super(basePath: '/api/settlements/settled');
}
