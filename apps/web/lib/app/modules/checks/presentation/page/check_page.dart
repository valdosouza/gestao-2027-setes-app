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
import '../../../../shared/search/advanced_search_panel.dart';
import '../../../../shared/search/search_criteria_chips.dart';
import '../../../../shared/search/search_criteria_datasource.dart';
import '../../../../shared/search/search_criterion.dart';
import '../../data/datasource/check_lookup_datasource.dart';
import '../../domain/entity/check_entity.dart';
import '../bloc/check_bloc.dart';
import 'check_action_dialogs.dart';
import 'check_detail_view.dart';

/// Tela de Cheques — interface 'checks', grupo Financeiro
/// (prompt_cheque_rastreabilidade.md D1–D10 + D7a–c). TELA DE PROCESSO:
/// LISTA em abas por estado DERIVADO (6 estados — abas ROLÁVEIS, mais
/// numerosas que o trio do boleto), filtro por número do cheque/emitente e
/// paginação; tap na linha abre o DETALHE dirigido pelo estado. SEM FAB:
/// o cheque só nasce pela baixa do faturamento (evento R, fora desta
/// tela) — não há "novo cheque" aqui.
class CheckPage extends StatefulWidget {
  const CheckPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage>
    with SingleTickerProviderStateMixin {
  late final CheckBloc _bloc;
  late final CheckLookupDatasource _lookup;
  late final TabController _tabs;
  final _filter = TextEditingController();

  static const _statuses = CheckStatus.all;

  /// Aba refletida na tela — evita reload redundante quando o bloc muda a
  /// aba sozinho.
  String _status = CheckStatus.custody;

  /// Pesquisa avançada (D-BA9/D-BA10 — molde service_orders): critérios
  /// servidos pela API; falha ao carregar = sem botão (a tela nunca quebra).
  late final SearchCriteriaDatasource _searchDatasource;
  List<SearchCriterion> _searchCriteria = const [];


  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CheckBloc>()
      ..add(const CheckListRequested(status: CheckStatus.custody, filter: ''));
    _lookup = Modular.get<CheckLookupDatasource>();
    _searchDatasource = Modular.get<SearchCriteriaDatasource>();
    _loadSearchCriteria();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  /// Troca de aba (TabBar.onTap — disparado UMA vez por toque, sem
  /// depender da animação do TabController terminar): dispara a recarga
  /// com o novo status. [addListener]/[indexIsChanging] não se mostrou
  /// confiável para isto (a notificação de "animação concluída" não
  /// chegou a disparar em teste manual — mesmo sintoma reproduzido no
  /// bank_slips, molde desta tela).
  void _onTabTapped(int index) {
    final status = _statuses[index];
    if (status != _status) {
      _status = status;
      _bloc.add(CheckListRequested(status: status));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _search() =>
      _bloc.add(CheckListRequested(filter: _filter.text.trim()));

  // -------------------------------------------------------------------
  // Lista (abas por estado derivado)
  // -------------------------------------------------------------------

  Future<void> _loadSearchCriteria() async {
    try {
      final criteria = await _searchDatasource.criteria();
      if (mounted) setState(() => _searchCriteria = criteria);
    } catch (_) {
      // sem critérios = sem botão; o filtro rápido segue funcionando
    }
  }

  /// Critério novo volta à página 1 (default do evento); a aba é mantida.
  void _applyCriteria(SearchCriteriaValues criteria) =>
      _bloc.add(CheckListRequested(criteria: criteria));

  Future<void> _openAdvancedSearch(SearchCriteriaValues current) async {
    final values = await showAdvancedSearch(
      context: context,
      criteria: _searchCriteria,
      current: current,
      datasource: _searchDatasource,
    );
    if (values != null) _applyCriteria(values);
  }

  Widget _buildRow(CheckListRow check) {
    final cells = [
      'forms.checks.numberRow'.tr(args: [check.number]),
      'forms.checks.issuerRow'.tr(args: [check.issuer]),
      'forms.checks.valueRow'.tr(args: [setesMoney(check.value)]),
      'forms.checks.dtCheckRow'.tr(args: [isoDateToDisplay(check.dtCheck)]),
    ];
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${check.id}')),
      title: SetesText(check.entityName ?? ''),
      subtitle: SetesText(cells.join(' · ')),
      onTap: () => _bloc.add(CheckViewRequested(check.id)),
    );
  }

  Widget _buildListBody(CheckListState state) {
    if (state.loading) return const SetesCircularProgressIndicator();
    if (state.items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildRow(state.items[index]),
    );
  }

  String _tabLabel(String status) => switch (status) {
        CheckStatus.bank => 'forms.checks.tabBank'.tr(),
        CheckStatus.factoring => 'forms.checks.tabFactoring'.tr(),
        CheckStatus.supplier => 'forms.checks.tabSupplier'.tr(),
        CheckStatus.refunded => 'forms.checks.tabRefunded'.tr(),
        CheckStatus.collection => 'forms.checks.tabCollection'.tr(),
        _ => 'forms.checks.tabCustody'.tr(),
      };

  Widget _buildList(CheckListState state) {
    _status = state.status;
    final tabIndex = _statuses.indexOf(state.status);
    if (tabIndex >= 0 && _tabs.index != tabIndex) _tabs.index = tabIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('register.listTitle'.tr(args: [widget.title])),
        actions: [
          if (_searchCriteria.isNotEmpty)
            IconButton(
              tooltip: 'search.title'.tr(),
              onPressed: () => _openAdvancedSearch(state.criteria),
              icon: Badge(
                isLabelVisible: !state.criteria.isEmpty,
                label: SetesText('${state.criteria.values.length}'),
                child: const Icon(Icons.manage_search),
              ),
            ),
          const RegisterConfigButton(moduleKey: 'checks'),
        ],
      ),
      body: Column(
        children: [
          // Abas ROLÁVEIS: 6 estados não cabem confortavelmente num TabBar
          // fixo como o trio do boleto (decisão de UX desta entrega).
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: _onTabTapped,
            tabs: [for (final status in _statuses) Tab(text: _tabLabel(status))],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SetesTextField(
                    label: 'forms.checks.filter'.tr(),
                    hint: 'register.filterHint'.tr(),
                    controller: _filter,
                    suffixIcon: Icons.search,
                    onSuffixPressed: _search,
                    onSubmitted: (_) => _search(),
                  ),
                  if (!state.criteria.isEmpty) ...[
                    const SizedBox(height: 8),
                    SearchCriteriaChips(
                      criteria: _searchCriteria,
                      values: state.criteria,
                      onChanged: _applyCriteria,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(child: _buildListBody(state)),
                  if (state.pageSize != null && state.total != null) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    RegisterPagingBar(
                      page: state.page,
                      pageSize: state.pageSize!,
                      total: state.total!,
                      configModuleKey: 'checks',
                      onPageChanged: (page) =>
                          _bloc.add(CheckListRequested(page: page)),
                      onPageSizeChanged: (size) =>
                          _bloc.add(CheckListRequested(pageSize: size)),
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

  Widget _buildDetail(CheckDetailState state) => CheckDetailView(
        key: ValueKey('check-${state.check.id}'),
        title: widget.title,
        check: state.check,
        saving: state.saving,
        lookup: _lookup,
        onBack: () => _bloc.add(const CheckBackToListPressed()),
        onDeposit: (dtRecord, bankAccountId) => _bloc.add(CheckDepositRequested(
            check: state.check, dtRecord: dtRecord, bankAccountId: bankAccountId)),
        onDiscount: (input) => _bloc.add(CheckDiscountRequested(
              check: state.check,
              dtRecord: input.dtRecord,
              factoringEntityId: input.factoringEntityId,
              bankAccountId: input.bankAccountId,
              feeValue: input.feeValue,
            )),
        onReturnRefund: (dtRecord, bankAccountId) =>
            _bloc.add(CheckReturnRefundRequested(
                check: state.check,
                dtRecord: dtRecord,
                bankAccountId: bankAccountId)),
        onReturnGood: (note) => _bloc
            .add(CheckReturnGoodRequested(check: state.check, note: note)),
        onPay: (input) => _bloc.add(CheckPayRequested(
              check: state.check,
              dtRecord: input.dtRecord,
              orderId: input.orderId,
              parcel: input.parcel,
            )),
        onReturn: (input) => _bloc.add(CheckReturnRequested(
            check: state.check, dtRecord: input.dtRecord, note: input.note)),
        onReverse: (event, reason) => _bloc.add(CheckReverseRequested(
            check: state.check, event: event, reason: reason)),
      );

  Widget _buildDetailLoading() => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => _bloc.add(const CheckBackToListPressed()),
          ),
          title: Text(widget.title),
        ),
        body: const SetesCircularProgressIndicator(),
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<CheckBloc, CheckState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CheckActionSuccess || current is CheckActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte (R1); falha = dialog. Os 409 de máquina de estados
        // (CHECK_NOT_IN_CUSTODY, CHECK_ALREADY_MOVED...) viram validação
        // com a mensagem da API; fields[] (400 do Zod) ancora pelo name do
        // payload das 7 ações.
        listener: (context, state) {
          if (state is CheckActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          final failure = (state as CheckActionFailure).failure;
          if (failure.fields.isNotEmpty &&
              !isSearchCriteriaFailure(failure)) {
            showChecksServerFieldFeedback(context, failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is CheckListState ||
            current is CheckDetailState ||
            current is CheckDetailLoadingState,
        builder: (context, state) => switch (state) {
          CheckDetailState() => _buildDetail(state),
          CheckDetailLoadingState() => _buildDetailLoading(),
          CheckListState() => _buildList(state),
          _ => _buildList(const CheckListState(loading: true)),
        },
      );
}
