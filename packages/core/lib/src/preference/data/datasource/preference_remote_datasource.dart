import '../../../shared/http/api_client.dart';

/// GET/PUT /api/core/preferences (decisão 14 — tb_user_has_preference).
class PreferenceRemoteDatasource {
  const PreferenceRemoteDatasource({required this.client});

  final ApiClient client;

  Future<Map<String, String>> getAll() async {
    final json = await client.get('/api/core/preferences');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  Future<void> save(String key, String value) async {
    await client.put('/api/core/preferences', {'key': key, 'value': value});
  }
}
