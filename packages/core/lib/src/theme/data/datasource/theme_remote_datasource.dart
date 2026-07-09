import '../../../shared/http/api_client.dart';
import '../../domain/entity/institution_theme.dart';

/// GET/PUT /api/core/theme (decisão 16).
class ThemeRemoteDatasource {
  const ThemeRemoteDatasource({required this.client});

  final ApiClient client;

  Future<InstitutionTheme> getTheme() async {
    final json = await client.get('/api/core/theme');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return InstitutionTheme(
      primaryColor: data['primaryColor'] as String?,
      secondaryColor: data['secondaryColor'] as String?,
      logoBase64: data['logoBase64'] as String?,
    );
  }

  Future<void> saveTheme({String? primaryColor, String? secondaryColor, String? logoBase64}) async {
    await client.put('/api/core/theme', {
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (secondaryColor != null) 'secondaryColor': secondaryColor,
      if (logoBase64 != null) 'logoBase64': logoBase64,
    });
  }
}
