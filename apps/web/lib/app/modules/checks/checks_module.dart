import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/check_datasource.dart';
import 'data/datasource/check_lookup_datasource.dart';
import 'data/repository/check_repository_impl.dart';
import 'domain/repository/check_repository.dart';
import 'domain/usecase/check_deposit.dart';
import 'domain/usecase/check_discount.dart';
import 'domain/usecase/check_get.dart';
import 'domain/usecase/check_getlist.dart';
import 'domain/usecase/check_pay.dart';
import 'domain/usecase/check_return_good.dart';
import 'domain/usecase/check_return_refund.dart';
import 'domain/usecase/check_return_to_origin.dart';
import 'domain/usecase/check_reverse.dart';
import 'presentation/bloc/check_bloc.dart';
import 'presentation/page/check_page.dart';

/// Módulo da interface 'checks' — Cheques (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). TELA DE PROCESSO do grupo Financeiro
/// (prompt_cheque_rastreabilidade.md D1–D10 + D7a–c): cheque ao PORTADOR
/// que substitui a dívida do cliente na baixa do faturamento — cabeçalho
/// imutável, estado SEMPRE derivado do último evento. O evento 'R'
/// (recebido) nasce só na transação do faturamento (fora desta tela); daqui
/// em diante o cheque é PORTADO através de depositar/descontar/retornar/
/// usar em pagamento/devolver/estornar. Gêmeo do /api/checks na
/// setes-api — o módulo fala SÓ com ele.
class ChecksModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<CheckDatasource>(
            (i) => CheckDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups das ações (contas/factoring/títulos a pagar) — datasource
        // DEDICADO, consumido direto pela page/detail view (não passa pelo bloc).
        Bind.lazySingleton<CheckLookupDatasource>(
            (i) => CheckLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<CheckRepository>(
            (i) => CheckRepositoryImpl(datasource: i.get<CheckDatasource>())),
        Bind.factory<CheckGetlist>(
            (i) => CheckGetlist(repository: i.get<CheckRepository>())),
        Bind.factory<CheckGet>(
            (i) => CheckGet(repository: i.get<CheckRepository>())),
        Bind.factory<CheckDeposit>(
            (i) => CheckDeposit(repository: i.get<CheckRepository>())),
        Bind.factory<CheckDiscount>(
            (i) => CheckDiscount(repository: i.get<CheckRepository>())),
        Bind.factory<CheckReturnRefund>(
            (i) => CheckReturnRefund(repository: i.get<CheckRepository>())),
        Bind.factory<CheckReturnGood>(
            (i) => CheckReturnGood(repository: i.get<CheckRepository>())),
        Bind.factory<CheckPay>(
            (i) => CheckPay(repository: i.get<CheckRepository>())),
        Bind.factory<CheckReturnToOrigin>(
            (i) => CheckReturnToOrigin(repository: i.get<CheckRepository>())),
        Bind.factory<CheckReverse>(
            (i) => CheckReverse(repository: i.get<CheckRepository>())),
        Bind.singleton<CheckBloc>((i) => CheckBloc(
              getlist: i.get<CheckGetlist>(),
              get: i.get<CheckGet>(),
              deposit: i.get<CheckDeposit>(),
              discount: i.get<CheckDiscount>(),
              returnRefund: i.get<CheckReturnRefund>(),
              returnGood: i.get<CheckReturnGood>(),
              pay: i.get<CheckPay>(),
              returnToOrigin: i.get<CheckReturnToOrigin>(),
              reverse: i.get<CheckReverse>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => CheckPage(
              title: args.data as String? ??
                  trCatalog('checks', 'Checks', prefix: 'menu.interfaces'),
            )),
      ];
}
