import 'package:core/core.dart';

import '../../domain/entity/customer_partnership.dart';

/// Datasource remoto da aba Parceria do cliente (Parceria v2 — angariação):
/// GET/PUT /api/customers/:id/partnership no módulo gêmeo customers da
/// setes-api. A aba é AUTÔNOMA (molde das abas Interfaces/Usuários do
/// institution): carrega ao abrir e salva com a lista completa — a API
/// sincroniza por colaborador (lista vazia remove a parceria).
abstract class CustomerPartnershipDatasource {
  /// Parceiros da parceria do cliente (nome via JOIN da API).
  Future<List<CustomerPartnershipPartner>> getPartners(int customerId);

  /// Grava a lista COMPLETA (vazia = remove a parceria). Erros de regra
  /// (soma dos ativos > 90, colaborador inválido) chegam como 400 da API.
  Future<void> putPartners(
      int customerId, List<CustomerPartnershipPartner> partners);

  /// Colaboradores para o lookup do dialog de parceiro.
  Future<List<CollaboratorLookupItem>> collaborators(String filter);
}

class CustomerPartnershipDatasourceImpl
    implements CustomerPartnershipDatasource {
  const CustomerPartnershipDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CustomerPartnershipPartner>> getPartners(int customerId) async {
    final json = await client.get('/api/customers/$customerId/partnership');
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    final partners = data['partners'] as List<dynamic>? ?? [];
    return partners
        .map((e) =>
            CustomerPartnershipPartner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> putPartners(
      int customerId, List<CustomerPartnershipPartner> partners) async {
    await client.put('/api/customers/$customerId/partnership', {
      'partners': [for (final partner in partners) partner.toJson()],
    });
  }

  @override
  Future<List<CollaboratorLookupItem>> collaborators(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/collaborators$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CollaboratorLookupItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
