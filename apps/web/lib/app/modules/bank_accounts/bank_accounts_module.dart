import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/bank_account_datasource.dart';
import 'data/repository/bank_account_repository_impl.dart';
import 'domain/repository/bank_account_repository.dart';
import 'domain/usecase/bank_account_delete.dart';
import 'domain/usecase/bank_account_get.dart';
import 'domain/usecase/bank_account_getlist.dart';
import 'domain/usecase/bank_account_post.dart';
import 'domain/usecase/bank_account_put.dart';
import 'presentation/bloc/bank_account_bloc.dart';
import 'presentation/page/bank_account_page.dart';

/// Módulo da interface 'bank-accounts' — Contas Bancárias (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Módulo Software House, grupo
/// Financeiro: conta corrente da institution apontando para o catálogo
/// central FEBRABAN (tb_bank). Gêmeo do /api/bank-accounts na setes-api.
class BankAccountsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<BankAccountDatasource>(
            (i) => BankAccountDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<BankAccountRepository>((i) => BankAccountRepositoryImpl(
            datasource: i.get<BankAccountDatasource>())),
        Bind.factory<BankAccountGetlist>((i) =>
            BankAccountGetlist(repository: i.get<BankAccountRepository>())),
        Bind.factory<BankAccountGet>(
            (i) => BankAccountGet(repository: i.get<BankAccountRepository>())),
        Bind.factory<BankAccountPost>(
            (i) => BankAccountPost(repository: i.get<BankAccountRepository>())),
        Bind.factory<BankAccountPut>(
            (i) => BankAccountPut(repository: i.get<BankAccountRepository>())),
        Bind.factory<BankAccountDelete>((i) =>
            BankAccountDelete(repository: i.get<BankAccountRepository>())),
        Bind.singleton<BankAccountBloc>((i) => BankAccountBloc(
              getlist: i.get<BankAccountGetlist>(),
              get:     i.get<BankAccountGet>(),
              post:    i.get<BankAccountPost>(),
              put:     i.get<BankAccountPut>(),
              delete:  i.get<BankAccountDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => BankAccountPage(
              title: args.data as String? ??
                  trCatalog('bank-accounts', 'Bank Accounts',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
