import 'package:core/core.dart';

import '../../../../shared/institution_interfaces/institution_interface_grant.dart';
import '../../../../shared/institution_interfaces/institution_interfaces_source.dart';
import '../../domain/entity/client_institution_entity.dart';

/// Datasource da tela "Interfaces dos clientes": /api/institution-interfaces
/// (D-PV11 — tela do grupo Super delegável pelo Super a usuário da Setes).
/// Também é a [InstitutionInterfacesSource] da aba compartilhada.
abstract class InstitutionInterfacesDatasource implements InstitutionInterfacesSource {
  /// Página da lista de estabelecimentos ([pageSize] null = config page_size).
  Future<PagedResult<ClientInstitutionEntity>> list(String filter, {int page = 1, int? pageSize});
}

class InstitutionInterfacesDatasourceImpl implements InstitutionInterfacesDatasource {
  const InstitutionInterfacesDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<ClientInstitutionEntity>> list(String filter, {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/institution-interfaces?${params.join('&')}');
    return PagedResult.fromJson(json, ClientInstitutionEntity.fromJson);
  }

  @override
  Future<List<InstitutionInterfaceGrant>> getInterfaces(int institutionId) async {
    final json = await client.get('/api/institution-interfaces/$institutionId');
    final data = json['data'] as List<dynamic>? ?? [];
    return data.map((e) => InstitutionInterfaceGrant.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> setInterfaces(int institutionId, List<int> interfaceIds) async {
    await client.put('/api/institution-interfaces/$institutionId', {'interfaceIds': interfaceIds});
  }
}
