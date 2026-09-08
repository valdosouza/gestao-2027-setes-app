import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/register/register_config_button.dart';
import '../../../../shared/register/register_paging_bar.dart';
import '../../data/datasource/bank_slip_lookup_datasource.dart';
import '../../domain/entity/bank_slip_entity.dart';
import '../bloc/bank_slip_bloc.dart';
import 'bank_slip_detail_view.dart';
import 'bank_slip_format.dart';
import 'bank_slip_issue_dialog.dart';

/// Tela de Boletos — interface 'bank-slips', grupo Financeiro
/// (prompt_boleto_emitido.md D1–D11). TELA DE PROCESSO: LISTA em abas por
/// estado DERIVADO (Abertos × Liquidados × Cancelados — `?status=`),
/// filtro por nosso número/documento, paginação e FAB "Emitir boleto"
/// (dialog carteira + títulos + vencimento); tap na linha abre o DETALHE
/// dirigido pelo estado (baixar/cancelar/estornar — cada ação chama a API
/// e recarrega o detalhe).
class BankSlipPage extends StatefulWidget {
  const BankSlipPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<BankSlipPage> createState() => _BankSlipPageState();
}

class _BankSlipPageState extends State<BankSlipPage>
    with SingleTickerProviderStateMixin {
  late final BankSlipBloc _bloc;
  late final BankSlipLookupDatasource _lookup;
  late final TabController _tabs;
  final _filter = TextEditingController();

  static const _statuses = [
    BankSlipStatus.open,
    BankSlipStatus.settled,
    BankSlipStatus.cancelled,
  ];

  /// Aba refletida na tela — evita reload redundante quando o bloc muda a
  /// aba sozinho (ex.: pós-emissão volta em Abertos).
  String _status = BankSlipStatus.open;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<BankSlipBloc>()
      ..add(const BankSlipListRequested(status: BankSlipStatus.open, filter: ''));
    _lookup = Modular.get<BankSlipLookupDatasource>();
    _tabs = TabController(length: _statuses.length, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final status = _statuses[_tabs.index];
      if (status != _status) {
        _status = status;
        _bloc.add(BankSlipListRequested(status: status));
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _search() =>
      _bloc.add(BankSlipListRequested(filter: _filter.text.trim()));

  /// FAB "Emitir boleto": dialog → POST (os 409 de negócio viram dialog
  /// de validação com a mensagem da API, via one-shot + ponte).
  Future<void> _openIssueDialog() async {
    final input = await showBankSlipIssueDialog(context, _lookup);
    if (input != null) _bloc.add(BankSlipIssueRequested(input));
  }

  // -------------------------------------------------------------------
  // Lista (abas por estado derivado)
  // -------------------------------------------------------------------

  Widget _buildRow(BankSlipListRow slip, String todayIso) {
    final theme = Theme.of(context);
    final overdue = slip.isOpen &&
        slip.dtExpiration != null &&
        slip.dtExpiration!.isNotEmpty &&
        slip.dtExpiration!.compareTo(todayIso) < 0;
    final cells = [
      'forms.bankSlip.ourNumberRow'.tr(args: [slip.ourNumber]),
      'forms.bankSlip.expirationRow'
          .tr(args: [isoDateToDisplay(slip.dtExpiration)]),
      'forms.bankSlip.valueRow'.tr(args: [setesMoney(slip.value)]),
      'forms.bankSlip.titlesCountRow'.tr(args: ['${slip.titles}']),
      if (overdue) 'forms.bankSlip.overdue'.tr(),
    ];
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${slip.id}')),
      title: SetesText(slip.customerName ?? ''),
      subtitle: SetesText(
        cells.join(' · '),
        // Vencido em aberto: destaque discreto com a cor de erro do tema.
        style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      onTap: () => _bloc.add(BankSlipViewRequested(slip.id)),
    );
  }

  Widget _buildListBody(BankSlipListState state) {
    if (state.loading) return const SetesCircularProgressIndicator();
    if (state.items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    final todayIso = bankSlipTodayIso();
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          _buildRow(state.items[index], todayIso),
    );
  }

  Widget _buildList(BankSlipListState state) {
    _status = state.status;
    final tabIndex = _statuses.indexOf(state.status);
    if (tabIndex >= 0 && _tabs.index != tabIndex) _tabs.index = tabIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('register.listTitle'.tr(args: [widget.title])),
        actions: const [
          RegisterConfigButton(moduleKey: 'bank-slips'),
        ],
      ),
      // FAB = Emitir boleto (padrão Icons.add da tela de pesquisa)
      floatingActionButton: FloatingActionButton(
        tooltip: 'forms.bankSlip.issue'.tr(),
        onPressed: _openIssueDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Abas no CORPO (padrão service_orders/settlements — no bottom
          // da AppBar as cores do tema somem no fundo primário).
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'forms.bankSlip.tabOpen'.tr()),
              Tab(text: 'forms.bankSlip.tabSettled'.tr()),
              Tab(text: 'forms.bankSlip.tabCancelled'.tr()),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SetesTextField(
                    label: 'forms.bankSlip.filter'.tr(),
                    hint: 'register.filterHint'.tr(),
                    controller: _filter,
                    suffixIcon: Icons.search,
                    onSuffixPressed: _search,
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildListBody(state)),
                  // Barra de paginação compartilhada no rodapé — só com
                  // os metadados da API no estado.
                  if (state.pageSize != null && state.total != null) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    RegisterPagingBar(
                      page: state.page,
                      pageSize: state.pageSize!,
                      total: state.total!,
                      configModuleKey: 'bank-slips',
                      onPageChanged: (page) =>
                          _bloc.add(BankSlipListRequested(page: page)),
                      onPageSizeChanged: (size) =>
                          _bloc.add(BankSlipListRequested(pageSize: size)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Detalhe
  // -------------------------------------------------------------------

  Widget _buildDetail(BankSlipDetailState state) => BankSlipDetailView(
        key: ValueKey('bank-slip-${state.slip.id}'),
        title: widget.title,
        slip: state.slip,
        saving: state.saving,
        onBack: () => _bloc.add(const BankSlipBackToListPressed()),
        onSettle: (paidValue, dtPayment) => _bloc.add(BankSlipSettleRequested(
            slip: state.slip, paidValue: paidValue, dtPayment: dtPayment)),
        onCancel: (note) =>
            _bloc.add(BankSlipCancelRequested(slip: state.slip, note: note)),
        onReverse: (reason) => _bloc
            .add(BankSlipReverseRequested(slip: state.slip, reason: reason)),
      );

  Widget _buildDetailLoading() => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => _bloc.add(const BankSlipBackToListPressed()),
          ),
          title: Text(widget.title),
        ),
        body: const SetesCircularProgressIndicator(),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BankSlipBloc, BankSlipState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is BankSlipActionSuccess ||
            current is BankSlipActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte (R1); falha = dialog (os 409 de negócio — título já
        // com boleto, clientes misturados, boleto fora do estado — viram
        // validação com a mensagem da API); 400 com fields[] ancora pelo
        // name do payload (dtExpiration/agreementId/titles — o dialog de
        // emissão já fechou, sem campo montado para focar).
        listener: (context, state) {
          if (state is BankSlipActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          final failure = (state as BankSlipActionFailure).failure;
          if (failure.fields.isNotEmpty) {
            showBankSlipServerFieldFeedback(context, failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is BankSlipListState ||
            current is BankSlipDetailState ||
            current is BankSlipDetailLoadingState,
        builder: (context, state) => switch (state) {
          BankSlipDetailState() => _buildDetail(state),
          BankSlipDetailLoadingState() => _buildDetailLoading(),
          BankSlipListState() => _buildList(state),
          _ => _buildList(const BankSlipListState(loading: true)),
        },
      );
}
