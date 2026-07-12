import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/users/datasource/user_datasource.dart';
import 'data/repository/user_repository_impl.dart';
import 'domain/repository/user_repository.dart';
import 'domain/usecase/user_delete.dart';
import 'domain/usecase/user_get.dart';
import 'domain/usecase/user_getlist.dart';
import 'domain/usecase/user_post.dart';
import 'domain/usecase/user_put.dart';
import 'presentation/bloc/user_bloc.dart';
import 'presentation/page/user_page.dart';

/// Módulo da interface 'users' (1 interface = 1 módulo —
/// ARQUITETURA_MODULOS.md). Cadastro de Usuário: cadeia do login
/// (tb_entity + tb_user + tb_mailing grupo 2) + vínculos com institutions.
class UsersModule extends Module {
  @override
  List<Bind> get binds => [
        // UserDatasource é bind GLOBAL do AppModule (shared/users — também
        // usado pela aba Usuários do Estabelecimento).
        Bind.lazySingleton<UserRepository>(
            (i) => UserRepositoryImpl(datasource: i.get<UserDatasource>())),
        Bind.factory<UserGetlist>(
            (i) => UserGetlist(repository: i.get<UserRepository>())),
        Bind.factory<UserGet>(
            (i) => UserGet(repository: i.get<UserRepository>())),
        Bind.factory<UserPost>(
            (i) => UserPost(repository: i.get<UserRepository>())),
        Bind.factory<UserPut>(
            (i) => UserPut(repository: i.get<UserRepository>())),
        Bind.factory<UserDelete>(
            (i) => UserDelete(repository: i.get<UserRepository>())),
        Bind.singleton<UserBloc>((i) => UserBloc(
              getlist: i.get<UserGetlist>(),
              get:     i.get<UserGet>(),
              post:    i.get<UserPost>(),
              put:     i.get<UserPut>(),
              delete:  i.get<UserDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => UserPage(
              title: args.data as String? ??
                  trCatalog('users', 'Users', prefix: 'menu.interfaces'),
            )),
      ];
}
