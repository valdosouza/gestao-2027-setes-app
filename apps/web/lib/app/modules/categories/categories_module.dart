import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/category_datasource.dart';
import 'data/repository/category_repository_impl.dart';
import 'domain/repository/category_repository.dart';
import 'domain/usecase/category_delete.dart';
import 'domain/usecase/category_getlist.dart';
import 'domain/usecase/category_post.dart';
import 'domain/usecase/category_put.dart';
import 'presentation/bloc/category_bloc.dart';
import 'presentation/page/category_page.dart';

/// Módulo da interface 'categories' — Categorias de produtos e serviços
/// (1 interface = 1 módulo, ARQUITETURA_MODULOS.md). Cadastro de CLIENTE,
/// grupo Cadastros: montado como ModuleRoute filho do Home; o título chega
/// via arguments, com fallback pelo catálogo para refresh direto na URL.
class CategoriesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CategoryDatasource>(
            (i) => CategoryDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CategoryRepository>((i) =>
            CategoryRepositoryImpl(datasource: i.get<CategoryDatasource>())),
        Bind.factory<CategoryGetlist>(
            (i) => CategoryGetlist(repository: i.get<CategoryRepository>())),
        Bind.factory<CategoryPost>(
            (i) => CategoryPost(repository: i.get<CategoryRepository>())),
        Bind.factory<CategoryPut>(
            (i) => CategoryPut(repository: i.get<CategoryRepository>())),
        Bind.factory<CategoryDelete>(
            (i) => CategoryDelete(repository: i.get<CategoryRepository>())),
        Bind.singleton<CategoryBloc>((i) => CategoryBloc(
              getlist: i.get<CategoryGetlist>(),
              post:    i.get<CategoryPost>(),
              put:     i.get<CategoryPut>(),
              delete:  i.get<CategoryDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CategoryPage(
              title: args.data as String? ??
                  trCatalog('categories', 'Categories',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
