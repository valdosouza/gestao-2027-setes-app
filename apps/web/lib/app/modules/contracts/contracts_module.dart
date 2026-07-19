import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/contract_datasource.dart';
import 'data/repository/contract_repository_impl.dart';
import 'domain/repository/contract_repository.dart';
import 'domain/usecase/contract_delete.dart';
import 'domain/usecase/contract_get.dart';
import 'domain/usecase/contract_getlist.dart';
import 'domain/usecase/contract_post.dart';
import 'domain/usecase/contract_put.dart';
import 'presentation/bloc/contract_bloc.dart';
import 'presentation/page/contract_page.dart';

/// Módulo da interface 'contracts' — Contratos de serviço (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Módulo Software House: contrato por
/// cliente com N itens (produto + valor mensal); alimenta a rotina mensal
/// do ciclo de serviços. Gêmeo do /api/contracts na setes-api.
class ContractsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ContractDatasource>(
            (i) => ContractDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<ContractRepository>((i) =>
            ContractRepositoryImpl(datasource: i.get<ContractDatasource>())),
        Bind.factory<ContractGetlist>(
            (i) => ContractGetlist(repository: i.get<ContractRepository>())),
        Bind.factory<ContractGet>(
            (i) => ContractGet(repository: i.get<ContractRepository>())),
        Bind.factory<ContractPost>(
            (i) => ContractPost(repository: i.get<ContractRepository>())),
        Bind.factory<ContractPut>(
            (i) => ContractPut(repository: i.get<ContractRepository>())),
        Bind.factory<ContractDelete>(
            (i) => ContractDelete(repository: i.get<ContractRepository>())),
        Bind.singleton<ContractBloc>((i) => ContractBloc(
              getlist: i.get<ContractGetlist>(),
              get:     i.get<ContractGet>(),
              post:    i.get<ContractPost>(),
              put:     i.get<ContractPut>(),
              delete:  i.get<ContractDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => ContractPage(
              title: args.data as String? ??
                  trCatalog('contracts', 'Contracts',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
