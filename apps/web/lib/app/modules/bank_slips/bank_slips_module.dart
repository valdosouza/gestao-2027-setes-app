import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/datasource/bank_slip_datasource.dart';
import 'data/datasource/bank_slip_lookup_datasource.dart';
import 'data/repository/bank_slip_repository_impl.dart';
import 'domain/repository/bank_slip_repository.dart';
import 'domain/usecase/bank_slip_bank_sync.dart';
import 'domain/usecase/bank_slip_cancel.dart';
import 'domain/usecase/bank_slip_get.dart';
import 'domain/usecase/bank_slip_pdf.dart';
import 'domain/usecase/bank_slip_reapply.dart';
import 'domain/usecase/bank_slip_refresh.dart';
import 'domain/usecase/bank_slip_register.dart';
import 'domain/usecase/bank_slip_getlist.dart';
import 'domain/usecase/bank_slip_issue.dart';
import 'domain/usecase/bank_slip_reverse.dart';
import 'domain/usecase/bank_slip_settle.dart';
import 'presentation/bloc/bank_slip_bloc.dart';
import 'presentation/page/bank_slip_page.dart';

/// Módulo da interface 'bank-slips' — Boletos (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). TELA DE PROCESSO do grupo Financeiro
/// (prompt_boleto_emitido.md D1–D11): lista por estado derivado, emissão
/// individual/agrupada, liquidação manual, cancelamento e estorno.
/// Gêmeo do /api/bank-slips na setes-api — o módulo fala SÓ com ele.
class BankSlipsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<BankSlipDatasource>(
            (i) => BankSlipDatasourceImpl(client: i.get<ApiClient>())),
        // Lookups da emissão (carteiras/títulos abertos) — datasource
        // DEDICADO, consumido direto pela page (não passa pelo bloc).
        Bind.lazySingleton<BankSlipLookupDatasource>(
            (i) => BankSlipLookupDatasourceImpl(client: i.get<ApiClient>())),
        Bind.lazySingleton<BankSlipRepository>((i) =>
            BankSlipRepositoryImpl(datasource: i.get<BankSlipDatasource>())),
        Bind.factory<BankSlipGetlist>(
            (i) => BankSlipGetlist(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipGet>(
            (i) => BankSlipGet(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipIssue>(
            (i) => BankSlipIssue(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipSettle>(
            (i) => BankSlipSettle(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipCancel>(
            (i) => BankSlipCancel(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipReverse>(
            (i) => BankSlipReverse(repository: i.get<BankSlipRepository>())),
        // Onda 2 — o boleto no banco (registro, consulta, PDF, consulta ativa)
        Bind.factory<BankSlipRegister>(
            (i) => BankSlipRegister(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipRefresh>(
            (i) => BankSlipRefresh(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipReapply>(
            (i) => BankSlipReapply(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipPdf>(
            (i) => BankSlipPdf(repository: i.get<BankSlipRepository>())),
        Bind.factory<BankSlipBankSync>(
            (i) => BankSlipBankSync(repository: i.get<BankSlipRepository>())),
        Bind.singleton<BankSlipBloc>((i) => BankSlipBloc(
              getlist: i.get<BankSlipGetlist>(),
              get:     i.get<BankSlipGet>(),
              issue:   i.get<BankSlipIssue>(),
              settle:  i.get<BankSlipSettle>(),
              cancel:  i.get<BankSlipCancel>(),
              reverse: i.get<BankSlipReverse>(),
              register: i.get<BankSlipRegister>(),
              refresh:  i.get<BankSlipRefresh>(),
              reapply:  i.get<BankSlipReapply>(),
              pdf:      i.get<BankSlipPdf>(),
              bankSync: i.get<BankSlipBankSync>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, args) => BankSlipPage(
              title: args.data as String? ??
                  trCatalog('bank-slips', 'Bank Slips',
                      prefix: 'menu.interfaces'),
            )),
      ];
}
