import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/tax_rule_datasource.dart';
import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import '../../domain/entity/tax_rule_list_item.dart';
import '../bloc/tax_rule_bloc.dart';
import '../widget/icms_st_tab.dart';
import '../widget/icms_tab.dart';
import '../widget/ii_tab.dart';
import '../widget/ipi_tab.dart';
import '../widget/pis_cofins_tab.dart';
import '../widget/selector_tab.dart';

/// Tela de Regras de Tributação — interface 'tax-rules' (1 interface = 1
/// módulo, ARQUITETURA_MODULOS.md). Fase Faturamento Fiscal e Financeiro:
/// regra decomposta em SELETOR (quando vale) + PEÇAS por tributo
/// (presença = incidência — decisões 1/23).
///
/// Form artesanal com SetesFormShell + TabBar de 6 abas (grupos NATURAIS:
/// Seletor + um tributo por aba, molde carriers): o bloc guarda o DRAFT da
/// regra inteira; as abas editam fatias via onChanged; salvar = 1 evento
/// com o objeto completo. Cada aba de tributo tem o TOGGLE "definir" —
/// desligado, a peça é OMITIDA do payload (nunca objeto vazio).
class TaxRulePage extends StatefulWidget {
  const TaxRulePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<TaxRulePage> createState() => _TaxRulePageState();
}

class _TaxRulePageState extends State<TaxRulePage> {
  late final TaxRuleBloc _bloc;
  late final StateLookupDatasource _stateLookup;

  /// Datasource do módulo — o form usa direto o lookup de CFOPs por alçada
  /// (leitura de apoio, sem estado — não passa pelo bloc).
  late final TaxRuleDatasource _datasource;

  /// Acesso ao form montado: ancora o fields[] do servidor no campo da aba
  /// certa (showServerFieldError — Framework de Mensagens, Onda B). Na
  /// lista o currentState é null.
  final _formViewKey = GlobalKey<_TaxRuleFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<TaxRuleBloc>()..add(const TaxRuleListRequested(''));
    _stateLookup = Modular.get<StateLookupDatasource>();
    _datasource = Modular.get<TaxRuleDatasource>();
  }

  /// Célula-título da linha: produto específico > NCM > regra geral.
  String _rowTitle(TaxRuleListItem item) {
    if ((item.productName ?? '').isNotEmpty) return item.productName!;
    if ((item.ncm ?? '').isNotEmpty) {
      return 'forms.taxRules.rowNcm'.tr(args: [item.ncm!]);
    }
    return 'forms.taxRules.rowGeneric'.tr();
  }

  /// Tributos presentes na regra (flags has* da lista) — "chips" textuais
  /// no subtítulo da linha.
  String _rowPieces(TaxRuleListItem item) => [
        if (item.hasIcms) 'forms.taxRules.chipIcms'.tr(),
        if (item.hasIcmsSt) 'forms.taxRules.chipIcmsSt'.tr(),
        if (item.hasIpi) 'forms.taxRules.chipIpi'.tr(),
        if (item.hasPisCofins) 'forms.taxRules.chipPisCofins'.tr(),
        if (item.hasIi) 'forms.taxRules.chipIi'.tr(),
      ].join(' + ');

  Widget _buildSearch(TaxRuleListState state) =>
      RegisterSearchPage<TaxRuleListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'tax-rules',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (item) => '${item.id}',
        rowBuilder: (item) => [
          _rowTitle(item),
          'forms.taxRules.rowOrigin'.tr(args: [item.origin]),
          'forms.taxRules.purpose${item.purpose}'.tr(),
          if ((item.stateName ?? '').isNotEmpty) item.stateName!,
          _rowPieces(item),
        ],
        // Paginação (D1/D3): metadados do estado montam a barra da fábrica;
        // filtro novo volta à página 1; troca de tamanho recarrega na 1
        // (a persistência da escolha é da fábrica — D4).
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(TaxRuleListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(TaxRuleListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(TaxRuleListRequested(filter)),
        onNew: () => _bloc.add(const TaxRuleNewPressed()),
        onView: (item) => _bloc.add(TaxRuleEditPressed(item)),
      );

  Widget _buildForm(TaxRuleFormState state) => _TaxRuleFormView(
        key: _formViewKey,
        title: widget.title,
        draft: state.draft,
        catalogs: state.catalogs,
        creating: state.creating,
        saving: state.saving,
        stateLookup: _stateLookup,
        searchCfops: _datasource.getCfopOptions,
        onDraftChanged: (draft) => _bloc.add(TaxRuleDraftChanged(draft)),
        onSave: () => _bloc.add(TaxRuleSaveRequested(
            draft: state.draft, creating: state.creating)),
        onBack: () => _bloc.add(const TaxRuleBackToListPressed()),
        onDelete: state.creating || state.draft.id == null
            ? null
            : () => _bloc.add(TaxRuleDeleteRequested(state.draft.id!)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TaxRuleBloc, TaxRuleState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is TaxRuleActionSuccess || current is TaxRuleActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo (aba
        // certa + foco) quando o form está montado.
        listener: (context, state) {
          if (state is TaxRuleActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as TaxRuleActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is TaxRuleListState || current is TaxRuleFormState,
        builder: (context, state) => switch (state) {
          TaxRuleFormState() => _buildForm(state),
          TaxRuleListState() => _buildSearch(state),
          _ => _buildSearch(const TaxRuleListState(loading: true)),
        },
      );
}

/// Form artesanal com SetesFormShell + TabBar/TabBarView (grupos naturais,
/// criar-formulario-cadastro.md item 2). O estado do form é o DRAFT no
/// bloc — este widget é apresentação: repassa fatias editadas.
///
/// Stateful pelo Framework de Mensagens (Onda B): o TabController próprio
/// permite à mecânica uma-pendência (R3) e ao fields[] do servidor TROCAR
/// para a aba do campo antes do foco (beforeFocus dos PendencyFields).
class _TaxRuleFormView extends StatefulWidget {
  const _TaxRuleFormView({
    required this.title,
    required this.draft,
    required this.catalogs,
    required this.creating,
    required this.saving,
    required this.stateLookup,
    required this.searchCfops,
    required this.onDraftChanged,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final TaxRuleDraft draft;
  final TaxRuleCatalogs catalogs;
  final bool creating;
  final bool saving;
  final StateLookupDatasource stateLookup;
  final CfopSearch searchCfops;
  final ValueChanged<TaxRuleDraft> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_TaxRuleFormView> createState() => _TaxRuleFormViewState();
}

class _TaxRuleFormViewState extends State<_TaxRuleFormView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  /// Ganchos de foco/marcação dos campos de texto da aba Seletor (R3).
  final _selectorHooks = SelectorTabHooks();

  /// Memória das fatias desligadas (L3 dos gates): o TabBarView DESCARTA a
  /// aba fora de tela — religar o toggle depois de trocar de aba perdia o
  /// digitado. A última fatia vista sobrevive aqui (este State fica montado
  /// o form inteiro) e volta pelo toggle da aba.
  IcmsData _lastIcms = const IcmsData();
  IcmsStData _lastIcmsSt = const IcmsStData();
  IpiData _lastIpi = const IpiData();
  PisCofinsData _lastPis = const PisCofinsData(kind: 'P');
  PisCofinsData _lastCofins = const PisCofinsData(kind: 'C');
  IiData _lastIi = const IiData();

  void _rememberSlices() {
    final d = _draft;
    if (d.icms != null) _lastIcms = d.icms!;
    if (d.icmsSt != null) _lastIcmsSt = d.icmsSt!;
    if (d.ipi != null) _lastIpi = d.ipi!;
    if (d.pis != null) _lastPis = d.pis!;
    if (d.cofins != null) _lastCofins = d.cofins!;
    if (d.ii != null) _lastIi = d.ii!;
  }

  @override
  void didUpdateWidget(covariant _TaxRuleFormView old) {
    super.didUpdateWidget(old);
    // Troca de registro zera a memória (não vazar fatia de outra regra).
    if (old.creating != widget.creating || old.draft.id != widget.draft.id) {
      _lastIcms = const IcmsData();
      _lastIcmsSt = const IcmsStData();
      _lastIpi = const IpiData();
      _lastPis = const PisCofinsData(kind: 'P');
      _lastCofins = const PisCofinsData(kind: 'C');
      _lastIi = const IiData();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _selectorHooks.dispose();
    super.dispose();
  }

  TaxRuleDraft get _draft => widget.draft;

  /// Alíquota/percentual: vazio ok; senão número entre 0 e 100.
  String? _rangePendency(String text, String labelKey) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final value = double.tryParse(t.replaceAll(',', '.'));
    if (value == null || value < 0 || value > 100) {
      return 'forms.taxRules.aliqInvalid'.tr(args: [labelKey.tr()]);
    }
    return null;
  }

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc), NA ORDEM das abas e dos campos na tela
  /// (R3). Os names carregam o PATH do payload (selector.ncm, icms.cstNr,
  /// pisCofins.P.cst...) — por eles o fields[] do servidor (Zod/catálogo)
  /// ancora no campo, trocando para a aba certa antes do foco.
  List<PendencyField> get _pendencyFields {
    final draft = _draft;
    final sel = draft.selector;
    void toSelector() => _tabs.animateTo(0);
    void toIcms() => _tabs.animateTo(1);
    void toIcmsSt() => _tabs.animateTo(2);
    void toIpi() => _tabs.animateTo(3);
    void toPisCofins() => _tabs.animateTo(4);
    void toIi() => _tabs.animateTo(5);

    return [
      // ------------------------- Seletor -------------------------
      PendencyField(
        name: 'selector.ncm',
        beforeFocus: toSelector,
        focusNode: _selectorHooks.ncmFocus,
        fieldKey: _selectorHooks.ncmKey,
        validate: () {
          final t = sel.ncm.trim();
          if (t.isEmpty) return null;
          return RegExp(r'^\d{2,8}$').hasMatch(t)
              ? null
              : 'forms.taxRules.ncmInvalid';
        },
      ),
      // Produto/Cliente não têm pendência local: são SOMENTE LEITURA na
      // tela (decisão 38 — preenchidos pelo cadastro de origem; a API
      // valida a existência com 422).
      // CFOP agora é LOOKUP por alçada (rodada 2026-09-01) — valor sempre
      // vem da lista; a âncora fica só para o fields[] do servidor.
      PendencyField(
        name: 'selector.cfopId',
        beforeFocus: toSelector,
        validate: () => null,
      ),
      // Regra sem NENHUM tributo não define nada (espelho do refine do
      // DTO — path 'selector').
      PendencyField(
        name: 'selector',
        beforeFocus: toIcms,
        validate: () =>
            draft.hasAnyPiece ? null : 'forms.taxRules.needPiece',
      ),
      // -------------------------- ICMS ---------------------------
      PendencyField(
        name: 'icms.cstNr',
        beforeFocus: toIcms,
        validate: () {
          final icms = draft.icms;
          if (icms == null) return null;
          return icms.cstNr == null && icms.csosn == null
              ? 'forms.taxRules.icmsNeedsCst'
              : null;
        },
      ),
      PendencyField(
        name: 'icms.aliq',
        beforeFocus: toIcms,
        validate: () => draft.icms == null
            ? null
            : _rangePendency(draft.icms!.aliq, 'forms.taxRules.icmsAliq'),
      ),
      PendencyField(
        name: 'icms.aliqReduction',
        beforeFocus: toIcms,
        validate: () => draft.icms == null
            ? null
            : _rangePendency(draft.icms!.aliqReduction,
                'forms.taxRules.icmsAliqReduction'),
      ),
      PendencyField(
        name: 'icms.baseReduction',
        beforeFocus: toIcms,
        validate: () => draft.icms == null
            ? null
            : _rangePendency(draft.icms!.baseReduction,
                'forms.taxRules.icmsBaseReduction'),
      ),
      PendencyField(
        name: 'icms.deferredAliq',
        beforeFocus: toIcms,
        // Sem diferimento o campo está OCULTO e não viaja no payload —
        // não pode gerar pendência em controle inacessível (L1, par do M1).
        validate: () => draft.icms == null || draft.icms!.deferred != 'S'
            ? null
            : _rangePendency(draft.icms!.deferredAliq,
                'forms.taxRules.icmsDeferredAliq'),
      ),
      // ------------------------- ICMS-ST -------------------------
      PendencyField(
        name: 'icmsSt',
        beforeFocus: toIcmsSt,
        validate: () =>
            draft.icmsSt != null && draft.icms == null
                ? 'forms.taxRules.stNeedsIcms'
                : null,
      ),
      // --------------------------- IPI ---------------------------
      PendencyField(
        name: 'ipi.cst',
        beforeFocus: toIpi,
        validate: () {
          final ipi = draft.ipi;
          if (ipi == null) return null;
          return (ipi.cst ?? '').isEmpty
              ? 'forms.taxRules.ipiNeedsCst'
              : null;
        },
      ),
      PendencyField(
        name: 'ipi.aliq',
        beforeFocus: toIpi,
        validate: () => draft.ipi == null
            ? null
            : _rangePendency(draft.ipi!.aliq, 'forms.taxRules.ipiAliq'),
      ),
      // ----------------------- PIS/COFINS ------------------------
      PendencyField(
        name: 'pisCofins.P.cst',
        beforeFocus: toPisCofins,
        validate: () {
          final pis = draft.pis;
          if (pis == null) return null;
          return (pis.cst ?? '').isEmpty
              ? 'forms.taxRules.pisNeedsCst'
              : null;
        },
      ),
      PendencyField(
        name: 'pisCofins.P.aliq',
        beforeFocus: toPisCofins,
        validate: () => draft.pis == null
            ? null
            : _rangePendency(draft.pis!.aliq, 'forms.taxRules.pisAliq'),
      ),
      PendencyField(
        name: 'pisCofins.C.cst',
        beforeFocus: toPisCofins,
        validate: () {
          final cofins = draft.cofins;
          if (cofins == null) return null;
          return (cofins.cst ?? '').isEmpty
              ? 'forms.taxRules.cofinsNeedsCst'
              : null;
        },
      ),
      PendencyField(
        name: 'pisCofins.C.aliq',
        beforeFocus: toPisCofins,
        validate: () => draft.cofins == null
            ? null
            : _rangePendency(
                draft.cofins!.aliq, 'forms.taxRules.cofinsAliq'),
      ),
      // --------------------------- II ----------------------------
      PendencyField(
        name: 'ii.iiAliq',
        beforeFocus: toIi,
        validate: () => draft.ii == null
            ? null
            : _rangePendency(draft.ii!.iiAliq, 'forms.taxRules.iiAliq'),
      ),
      PendencyField(
        name: 'ii.irpjAliq',
        beforeFocus: toIi,
        validate: () => draft.ii == null
            ? null
            : _rangePendency(
                draft.ii!.irpjAliq, 'forms.taxRules.iiIrpjAliq'),
      ),
      PendencyField(
        name: 'ii.csllAliq',
        beforeFocus: toIi,
        validate: () => draft.ii == null
            ? null
            : _rangePendency(
                draft.ii!.csllAliq, 'forms.taxRules.iiCsllAliq'),
      ),
      PendencyField(
        name: 'ii.afrmmAliq',
        beforeFocus: toIi,
        validate: () => draft.ii == null
            ? null
            : _rangePendency(
                draft.ii!.afrmmAliq, 'forms.taxRules.iiAfrmmAliq'),
      ),
      PendencyField(
        name: 'ii.siscomexAliq',
        beforeFocus: toIi,
        validate: () => draft.ii == null
            ? null
            : _rangePendency(
                draft.ii!.siscomexAliq, 'forms.taxRules.iiSiscomexAliq'),
      ),
    ];
  }

  /// Traduz os paths de ARRAY do Zod (`pisCofins.0.cst`) para os paths por
  /// kind que o form declara (`pisCofins.P.cst`): o índice segue a ordem do
  /// toJson do draft — P primeiro quando presente (gate M2; sem isso o
  /// fields[] de PIS/COFINS nunca ancorava e caía no dialog cru).
  Failure _mapPisCofinsPaths(Failure failure) {
    final kinds = [
      if (_draft.pis != null) 'P',
      if (_draft.cofins != null) 'C',
    ];
    final mapped = failure.fields.map((f) {
      final match = RegExp(r'^pisCofins\.(\d+)\.(.+)$').firstMatch(f.field);
      if (match == null) return f;
      final index = int.parse(match.group(1)!);
      if (index >= kinds.length) return f;
      return FailureField(
        field: 'pisCofins.${kinds[index]}.${match.group(2)}',
        message: f.message,
      );
    }).toList();
    return Failure(
      message: failure.message,
      statusCode: failure.statusCode,
      fields: mapped,
      code: failure.code,
      supportRef: failure.supportRef,
    );
  }

  /// Ancora o fields[] do envelope 400/422 no campo — aba certa + foco
  /// (chamado pelo listener do bloc via GlobalKey).
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(
          context, _mapPisCofinsPaths(failure), _pendencyFields);

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    widget.onSave();
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4): Sim = excluir;
  /// Cancelar (ou fechar) = nada.
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    _rememberSlices();
    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      // Troca de registro reinicia abas e controllers.
      child: KeyedSubtree(
        key: ValueKey(
            widget.creating ? 'tax-rule-new' : 'tax-rule-${draft.id}'),
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'forms.taxRules.tabSelector'.tr()),
                Tab(text: 'forms.taxRules.tabIcms'.tr()),
                Tab(text: 'forms.taxRules.tabIcmsSt'.tr()),
                Tab(text: 'forms.taxRules.tabIpi'.tr()),
                Tab(text: 'forms.taxRules.tabPisCofins'.tr()),
                Tab(text: 'forms.taxRules.tabIi'.tr()),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  SelectorTab(
                    value: draft.selector,
                    stateLookup: widget.stateLookup,
                    searchCfops: widget.searchCfops,
                    hooks: _selectorHooks,
                    onChanged: (selector) => widget
                        .onDraftChanged(draft.copyWith(selector: selector)),
                  ),
                  IcmsTab(
                    value: draft.icms,
                    restore: _lastIcms,
                    catalogs: widget.catalogs,
                    // Desligar o ICMS derruba a ST junto (ST exige o
                    // próprio — P3.3): sem isso o toggle da ST ficava
                    // desabilitado E ligado, beco sem saída (gate M1).
                    onChanged: (icms) => widget.onDraftChanged(icms == null
                        ? draft.copyWith(
                            icms: () => null, icmsSt: () => null)
                        : draft.copyWith(icms: () => icms)),
                  ),
                  IcmsStTab(
                    value: draft.icmsSt,
                    restore: _lastIcmsSt,
                    icmsOn: draft.icms != null,
                    catalogs: widget.catalogs,
                    onChanged: (icmsSt) => widget.onDraftChanged(
                        draft.copyWith(icmsSt: () => icmsSt)),
                  ),
                  IpiTab(
                    value: draft.ipi,
                    restore: _lastIpi,
                    catalogs: widget.catalogs,
                    onChanged: (ipi) => widget
                        .onDraftChanged(draft.copyWith(ipi: () => ipi)),
                  ),
                  PisCofinsTab(
                    pis: draft.pis,
                    cofins: draft.cofins,
                    restorePis: _lastPis,
                    restoreCofins: _lastCofins,
                    catalogs: widget.catalogs,
                    onPisChanged: (pis) => widget
                        .onDraftChanged(draft.copyWith(pis: () => pis)),
                    onCofinsChanged: (cofins) => widget.onDraftChanged(
                        draft.copyWith(cofins: () => cofins)),
                  ),
                  IiTab(
                    value: draft.ii,
                    restore: _lastIi,
                    onChanged: (ii) =>
                        widget.onDraftChanged(draft.copyWith(ii: () => ii)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
