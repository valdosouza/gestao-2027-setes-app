import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/bank_charge_agreement_datasource.dart';
import 'data/repository/bank_charge_agreement_repository_impl.dart';
import 'domain/repository/bank_charge_agreement_repository.dart';
import 'domain/usecase/bank_charge_agreement_delete.dart';
import 'domain/usecase/bank_charge_agreement_get.dart';
import 'domain/usecase/bank_charge_agreement_getlist.dart';
import 'domain/usecase/bank_charge_agreement_post.dart';
import 'domain/usecase/bank_charge_agreement_put.dart';
import 'presentation/bloc/bank_charge_agreement_bloc.dart';
import 'presentation/page/bank_charge_agreement_page.dart';

/// Módulo da interface 'bank-charge-agreements' — Carteiras de Cobrança
/// (contratação de cobrança com o banco; o boleto CONGELA estas taxas/
/// instruções na emissão). Grupo Financeiro (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Gêmeo do /api/bank-charge-agreements na
/// setes-api (cadastro de CLIENTE, sem superGuard).
class BankChargeAgreementsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<BankChargeAgreementDatasource>((i) =>
            BankChargeAgreementDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<BankChargeAgreementRepository>((i) =>
            BankChargeAgreementRepositoryImpl(
                datasource: i.get<BankChargeAgreementDatasource>())),
        Bind.factory<BankChargeAgreementGetlist>((i) =>
            BankChargeAgreementGetlist(
                repository: i.get<BankChargeAgreementRepository>())),
        Bind.factory<BankChargeAgreementGet>((i) => BankChargeAgreementGet(
            repository: i.get<BankChargeAgreementRepository>())),
        Bind.factory<BankChargeAgreementPost>((i) => BankChargeAgreementPost(
            repository: i.get<BankChargeAgreementRepository>())),
        Bind.factory<BankChargeAgreementPut>((i) => BankChargeAgreementPut(
            repository: i.get<BankChargeAgreementRepository>())),
        Bind.factory<BankChargeAgreementDelete>((i) =>
            BankChargeAgreementDelete(
                repository: i.get<BankChargeAgreementRepository>())),
        Bind.singleton<BankChargeAgreementBloc>((i) => BankChargeAgreementBloc(
              getlist: i.get<BankChargeAgreementGetlist>(),
              get:     i.get<BankChargeAgreementGet>(),
              post:    i.get<BankChargeAgreementPost>(),
              put:     i.get<BankChargeAgreementPut>(),
              delete:  i.get<BankChargeAgreementDelete>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => BankChargeAgreementPage(
              title: args.data as String? ??
                  trCatalog('bank-charge-agreements', 'Bank Charge Agreements',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
