import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/institution_interfaces_datasource.dart';
import 'data/repository/institution_interfaces_repository_impl.dart';
import 'domain/repository/institution_interfaces_repository.dart';
import 'domain/usecase/institution_interfaces_getlist.dart';
import 'presentation/bloc/institution_interfaces_bloc.dart';
import 'presentation/page/institution_interfaces_page.dart';

/// Módulo da interface 'institution-interfaces' — "Interfaces dos clientes"
/// (D-PV11, 2026-10-18): o vínculo estabelecimento × interfaces de cada
/// cliente, tela do grupo Super delegável pelo Super a usuário da Setes.
/// Gêmeo do /api/institution-interfaces na setes-api.
class InstitutionInterfacesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<InstitutionInterfacesDatasource>(
            (i) => InstitutionInterfacesDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<InstitutionInterfacesRepository>((i) =>
            InstitutionInterfacesRepositoryImpl(datasource: i.get<InstitutionInterfacesDatasource>())),
        Bind.factory<InstitutionInterfacesGetlist>(
            (i) => InstitutionInterfacesGetlist(repository: i.get<InstitutionInterfacesRepository>())),
        Bind.singleton<InstitutionInterfacesBloc>(
            (i) => InstitutionInterfacesBloc(getList: i.get<InstitutionInterfacesGetlist>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => InstitutionInterfacesPage(
              title: args.data as String? ??
                  trCatalog('institution-interfaces', 'Client interfaces', prefix: 'menu.interfaces'),
            )),
      ];
}
