import 'package:core/core.dart';

import '../../domain/entity/category_entity.dart';

/// Datasource remoto de Categoria: /api/categories na setes-api (módulo
/// gêmeo, SEM superGuard — cadastro do cliente; escopo por institution
/// vem do JWT). A lista chega ORDENADA por posit_level (ordem da árvore).
abstract class CategoryDatasource {
  Future<List<CategoryEntity>> getList(String kind);
  Future<int> post(CategoryEntity category);
  Future<void> put(CategoryEntity category);
  Future<void> delete(int id);
}

class CategoryDatasourceImpl implements CategoryDatasource {
  const CategoryDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CategoryEntity>> getList(String kind) async {
    final json = await client.get('/api/categories?kind=$kind');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CategoryEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O id é gerado pelo backend (MAX+1 por institution) — o body não envia
  /// id; o posit_level nasce lá (caminho do pai + código).
  @override
  Future<int> post(CategoryEntity category) async {
    final json = await client.post('/api/categories', category.toCreateJson());
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(CategoryEntity category) async {
    await client.put('/api/categories/${category.id}', category.toUpdateJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/categories/$id');
  }
}
