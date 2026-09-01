import 'package:core/core.dart';

import '../../domain/entity/object_establishment.dart';

/// Datasource remoto do PRÓPRIO estabelecimento: /api/establishment na
/// setes-api. NUNCA existe `:id` na URL — o institutionId é sempre
/// implícito (token do usuário logado).
abstract class EstablishmentDatasource {
  Future<ObjectEstablishment> get();
  Future<ObjectEstablishment> put(ObjectEstablishment establishment);
}

class EstablishmentDatasourceImpl implements EstablishmentDatasource {
  const EstablishmentDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<ObjectEstablishment> get() async {
    final json = await client.get('/api/establishment');
    return ObjectEstablishment.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<ObjectEstablishment> put(ObjectEstablishment establishment) async {
    final json =
        await client.put('/api/establishment', establishment.toJson());
    return ObjectEstablishment.fromJson(json['data'] as Map<String, dynamic>);
  }
}
