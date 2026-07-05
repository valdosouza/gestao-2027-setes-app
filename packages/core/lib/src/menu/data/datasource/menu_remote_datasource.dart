import '../../../shared/http/api_client.dart';
import '../model/menu_model.dart';

class MenuRemoteDatasource {
  const MenuRemoteDatasource({required this.client});

  final ApiClient client;

  Future<List<MenuModuleModel>> getMenus() async {
    final json = await client.get('/api/core/menus');
    return (json['data'] as List<dynamic>? ?? [])
        .map((e) => MenuModuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
