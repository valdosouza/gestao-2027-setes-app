import 'package:core/core.dart';

import '../../domain/entity/service_entity.dart';

/// Lookups de apoio do form de Serviço (categoria, plano financeiro, regra
/// de tributação de serviço e, na fase IBS/CBS, NBS/cClassTrib/cIndOp) —
/// SÓ LEITURA, endpoints do próprio módulo (/api/services/*). É o que a
/// page pode consumir direto (padrão StateLookupDatasource): a page NUNCA
/// toca o ServiceDatasource principal (escrita passa por usecase/bloc).
/// Promover para app/shared/lookup quando um segundo módulo precisar.
abstract class ServiceLookupDatasource {
  Future<List<ServiceLookup>> categories(String filter);
  Future<List<ServiceLookup>> financialPlans(String filter);

  /// Regras de tributação de serviço da institution (D1 — FK literal):
  /// {id, description "1.02 · Curitiba/PR · 5.00%"}.
  Future<List<ServiceLookup>> taxRules(String filter);

  /// NBS do catálogo oficial (filtro por descrição ou início do código):
  /// {code "101011100", description "101011100 — Serviços de ..."}.
  Future<List<ServiceCodeLookup>> nbs(String filter);

  /// cClassTrib vigentes HOJE e aceitos na NFS-e:
  /// {code "000001", description "000 · 000001 — nome"}.
  Future<List<ServiceCodeLookup>> ibscbsClassifications(String filter);

  /// cIndOp (Anexo VII) aceitos na NFS-e:
  /// {code "100301", description "100301 — descrição"}.
  Future<List<ServiceCodeLookup>> ibscbsPlaceIndicators(String filter);
}

class ServiceLookupDatasourceImpl implements ServiceLookupDatasource {
  const ServiceLookupDatasourceImpl({required this.client});

  final ApiClient client;

  Future<List<Map<String, dynamic>>> _rows(String path, String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/services/$path$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<ServiceLookup>> _lookup(String path, String filter) async =>
      (await _rows(path, filter)).map(ServiceLookup.fromJson).toList();

  /// Listas da fase IBS/CBS: chave `code` TEXTUAL (não `id` numérico).
  Future<List<ServiceCodeLookup>> _codeLookup(
          String path, String filter) async =>
      (await _rows(path, filter)).map(ServiceCodeLookup.fromJson).toList();

  @override
  Future<List<ServiceLookup>> categories(String filter) =>
      _lookup('categories', filter);

  @override
  Future<List<ServiceLookup>> financialPlans(String filter) =>
      _lookup('financial-plans', filter);

  @override
  Future<List<ServiceLookup>> taxRules(String filter) =>
      _lookup('tax-rules', filter);

  @override
  Future<List<ServiceCodeLookup>> nbs(String filter) =>
      _codeLookup('nbs', filter);

  @override
  Future<List<ServiceCodeLookup>> ibscbsClassifications(String filter) =>
      _codeLookup('ibscbs-classifications', filter);

  @override
  Future<List<ServiceCodeLookup>> ibscbsPlaceIndicators(String filter) =>
      _codeLookup('ibscbs-place-indicators', filter);
}
