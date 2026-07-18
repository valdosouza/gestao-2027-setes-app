import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/payment_type_datasource.dart';
import 'data/repository/payment_type_repository_impl.dart';
import 'domain/repository/payment_type_repository.dart';
import 'domain/usecase/payment_type_delete.dart';
import 'domain/usecase/payment_type_getlist.dart';
import 'domain/usecase/payment_type_post.dart';
import 'domain/usecase/payment_type_put.dart';
import 'presentation/bloc/payment_type_bloc.dart';
import 'presentation/page/payment_type_page.dart';

/// Módulo da interface 'payment-types' — Formas de Pagamento (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Cadastro de CLIENTE no grupo NOVO
/// Financeiro: catálogo central compartilhado (o cliente inicia) + vínculo
/// por institution.
class PaymentTypesModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<PaymentTypeDatasource>(
            (i) => PaymentTypeDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<PaymentTypeRepository>((i) =>
            PaymentTypeRepositoryImpl(
                datasource: i.get<PaymentTypeDatasource>())),
        Bind.factory<PaymentTypeGetlist>((i) =>
            PaymentTypeGetlist(repository: i.get<PaymentTypeRepository>())),
        Bind.factory<PaymentTypePost>((i) =>
            PaymentTypePost(repository: i.get<PaymentTypeRepository>())),
        Bind.factory<PaymentTypePut>((i) =>
            PaymentTypePut(repository: i.get<PaymentTypeRepository>())),
        Bind.factory<PaymentTypeDelete>((i) =>
            PaymentTypeDelete(repository: i.get<PaymentTypeRepository>())),
        Bind.singleton<PaymentTypeBloc>((i) => PaymentTypeBloc(
              getlist: i.get<PaymentTypeGetlist>(),
              post:    i.get<PaymentTypePost>(),
              put:     i.get<PaymentTypePut>(),
              delete:  i.get<PaymentTypeDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => PaymentTypePage(
              title: args.data as String? ??
                  trCatalog('payment-types', 'Payment Types',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
