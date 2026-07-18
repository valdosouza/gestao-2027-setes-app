import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/financial_plan_entity.dart';
import '../bloc/financial_plan_bloc.dart';

/// Tela do Plano de Contas — interface 'financial-plans', 2º cadastro em
/// ÁRVORE (porta do Delphi reg_plano_contas.pas; padrão do tipo árvore do
/// molde categories). Árvore ÚNICA: FAB = novo NÍVEL raiz, ação "+" no nó
/// = novo SUBNÍVEL, clique no nó = edição. Mover de pai é feito na edição
/// (lookup do nível superior — a API recalcula o posit_level da subárvore);
/// excluir com subníveis é bloqueado pela API (409 vira SnackBar).
/// Natureza/Tipo/Nível são radios do form (semântica do Delphi).
class FinancialPlanPage extends StatefulWidget {
  const FinancialPlanPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<FinancialPlanPage> createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends State<FinancialPlanPage> {
  late final FinancialPlanBloc _bloc;

  /// Última árvore carregada — alimenta o lookup de "nível superior" do
  /// form (mover de pai) sem nova consulta.
  List<FinancialPlanEntity> _lastItems = const [];

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<FinancialPlanBloc>()
      ..add(const FinancialPlanTreeRequested());
  }

  /// Engrenagem padrão da lista (Framework de Configurações, decisão 11) —
  /// replicada manualmente porque a tela de árvore não usa a fábrica.
  void _openConfigs() {
    Modular.to.navigate('/home/interface-configs/', arguments: {
      'title': trCatalog('interface-configs', 'Interface Configs',
          prefix: 'menu.interfaces'),
      'moduleKey': 'financial-plans',
      'returnTo': Modular.to.path,
    });
  }

  /// Monta os nós a partir da lista ordenada por posit_level. Subtítulo =
  /// domínios da conta (Natureza/Tipo/Nível — ajuda a ler a árvore).
  List<SetesTreeNode<FinancialPlanEntity>> _buildNodes(
      List<FinancialPlanEntity> items) {
    final byParent = <int?, List<FinancialPlanEntity>>{};
    for (final item in items) {
      byParent.putIfAbsent(item.parentId, () => []).add(item);
    }
    String subtitle(FinancialPlanEntity item) => [
          item.source == 'D'
              ? 'forms.financialPlan.sourceDebit'.tr()
              : 'forms.financialPlan.sourceCredit'.tr(),
          item.kind == 'R'
              ? 'forms.financialPlan.kindResult'.tr()
              : 'forms.financialPlan.kindCost'.tr(),
          item.cluster == 'A'
              ? 'forms.financialPlan.clusterAnalytic'.tr()
              : 'forms.financialPlan.clusterSynthetic'.tr(),
          if (!item.active) 'forms.financialPlan.inactiveRow'.tr(),
        ].join(' · ');
    SetesTreeNode<FinancialPlanEntity> node(FinancialPlanEntity item) =>
        SetesTreeNode(
          id: item.id,
          label: item.description ?? '',
          subtitle: subtitle(item),
          data: item,
          children: [for (final c in byParent[item.id] ?? []) node(c)],
        );
    return [for (final root in byParent[null] ?? []) node(root)];
  }

  Widget _buildTree(FinancialPlanTreeState state) {
    _lastItems = state.items;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('register.listTitle'.tr(args: [widget.title])),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'register.configTooltip'.tr(),
            onPressed: _openConfigs,
          ),
        ],
      ),
      // FAB = novo NÍVEL raiz (Delphi: opção "Nível")
      floatingActionButton: FloatingActionButton(
        tooltip: 'forms.financialPlan.newRoot'.tr(),
        onPressed: () => _bloc.add(const FinancialPlanNewPressed()),
        child: const Icon(Icons.add),
      ),
      body: state.loading
          ? const SetesCircularProgressIndicator()
          : SetesTreeView<FinancialPlanEntity>(
              nodes: _buildNodes(state.items),
              emptyText: 'register.emptyList'.tr(),
              onTap: (item) => _bloc.add(FinancialPlanEditPressed(item)),
              // Ação "+" no nó = novo SUBNÍVEL (Delphi: "SubNível")
              onAddChild: (item) =>
                  _bloc.add(FinancialPlanNewPressed(parent: item)),
              addChildTooltip: 'forms.financialPlan.newChild'.tr(),
            ),
    );
  }

  Widget _buildForm(FinancialPlanFormState state) => _FinancialPlanFormView(
        key: ValueKey(state.editing?.id ?? 'financial-plan-new'),
        title: widget.title,
        state: state,
        items: _lastItems,
        onSave: (plan, creating) => _bloc
            .add(FinancialPlanSaveRequested(plan: plan, creating: creating)),
        onBack: () => _bloc.add(const FinancialPlanBackToTreePressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(FinancialPlanDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<FinancialPlanBloc, FinancialPlanState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is FinancialPlanActionSuccess ||
            current is FinancialPlanActionFailure,
        listener: (context, state) {
          final message = state is FinancialPlanActionSuccess
              ? state.messageKey.tr()
              : (state as FinancialPlanActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is FinancialPlanTreeState ||
            current is FinancialPlanFormState,
        builder: (context, state) => switch (state) {
          FinancialPlanFormState() => _buildForm(state),
          FinancialPlanTreeState() => _buildTree(state),
          _ => _buildTree(const FinancialPlanTreeState(loading: true)),
        },
      );
}

/// Form da conta (SetesFormShell): descrição + nível superior (lookup da
/// árvore — trocar o pai = mover) + radios Natureza (C/D), Tipo (C/R) e
/// Nível (S/A) — semântica do reg_plano_contas.pas — + ativo.
class _FinancialPlanFormView extends StatefulWidget {
  const _FinancialPlanFormView({
    required this.title,
    required this.state,
    required this.items,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final FinancialPlanFormState state;
  final List<FinancialPlanEntity> items;
  final void Function(FinancialPlanEntity plan, bool creating) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_FinancialPlanFormView> createState() => _FinancialPlanFormViewState();
}

class _FinancialPlanFormViewState extends State<_FinancialPlanFormView> {
  late final TextEditingController _description;
  int? _parentId;
  String? _parentName;
  late String _source;
  late String _kind;
  late String _cluster;
  late bool _active;

  FinancialPlanEntity? get _editing => widget.state.editing;
  bool get _creating => _editing == null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _description = TextEditingController(text: editing?.description ?? '');
    // Defaults do Delphi (radios em ItemIndex 0): Credora/Custo/Sintética
    _source  = editing?.source ?? 'C';
    _kind    = editing?.kind ?? 'C';
    _cluster = editing?.cluster ?? 'S';
    _active  = editing?.active ?? true;
    if (editing != null) {
      _parentId = editing.parentId;
      _parentName = _nameOf(editing.parentId);
    } else {
      _parentId = widget.state.initialParentId;
      _parentName = widget.state.initialParentName ??
          _nameOf(widget.state.initialParentId);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  String? _nameOf(int? id) {
    if (id == null) return null;
    for (final item in widget.items) {
      if (item.id == id) return item.description;
    }
    return null;
  }

  /// Candidatos a nível superior: exclui o próprio nó e seus descendentes
  /// (a API revalida — aqui é UX).
  Future<List<FinancialPlanEntity>> _searchParents(String filter) async {
    final editing = _editing;
    final lower = filter.toLowerCase();
    return widget.items.where((item) {
      if (editing != null &&
          (item.id == editing.id ||
              item.positLevel.startsWith('${editing.positLevel}.'))) {
        return false;
      }
      return lower.isEmpty ||
          (item.description ?? '').toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> _pickParent() async {
    final picked = await showSetesLookup<FinancialPlanEntity>(
      context: context,
      title: 'forms.financialPlan.parent'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _searchParents,
      itemId: (p) => p.id,
      itemLabel: (p) => p.description ?? '',
    );
    if (picked != null) {
      setState(() {
        _parentId = picked.id;
        _parentName = picked.description;
      });
    }
  }

  void _save() {
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: SetesText('register.requiredField'
              .tr(args: ['forms.financialPlan.description'.tr()]))));
      return;
    }
    widget.onSave(
      FinancialPlanEntity(
        id:          _editing?.id ?? 0, // ignorado no POST
        description: _description.text.trim(),
        parentId:    _parentId,
        source:      _source,
        kind:        _kind,
        cluster:     _cluster,
        active:      _active,
      ),
      _creating,
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('register.confirmDelete'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'register.delete'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) => SetesFormShell(
        title: widget.title,
        saving: widget.state.saving,
        onBack: widget.onBack,
        onSave: _save,
        onDelete: widget.onDelete != null ? _confirmDelete : null,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_creating) ...[
              SetesTextField(
                label: 'forms.financialPlan.code'.tr(),
                controller: TextEditingController(text: '${_editing!.id}'),
                readOnly: true,
              ),
              const SizedBox(height: 16),
            ],
            SetesTextField(
              label: 'forms.financialPlan.description'.tr(),
              controller: _description,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // Nível superior (lookup da árvore) — trocar = MOVER;
            // limpar = virar nível raiz.
            SetesLookupField(
              label: 'forms.financialPlan.parent'.tr(),
              display: _parentName ?? 'forms.financialPlan.rootLevel'.tr(),
              onSearch: _pickParent,
              onClear: () => setState(() {
                _parentId = null;
                _parentName = null;
              }),
            ),
            const SizedBox(height: 16),
            ExcludeFocusTraversal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Natureza (Rg_Natureza do Delphi): Credora × Devedora
                  SetesRadioGroup<String>(
                    label: 'forms.financialPlan.source'.tr(),
                    value: _source,
                    options: [
                      SetesRadioOption(
                          value: 'C',
                          label: 'forms.financialPlan.sourceCredit'.tr()),
                      SetesRadioOption(
                          value: 'D',
                          label: 'forms.financialPlan.sourceDebit'.tr()),
                    ],
                    onChanged: (v) => setState(() => _source = v ?? 'C'),
                  ),
                  const SizedBox(height: 8),
                  // Tipo da Conta (Rg_Tipo): Centro de Custo × Resultado
                  SetesRadioGroup<String>(
                    label: 'forms.financialPlan.kind'.tr(),
                    value: _kind,
                    options: [
                      SetesRadioOption(
                          value: 'C',
                          label: 'forms.financialPlan.kindCost'.tr()),
                      SetesRadioOption(
                          value: 'R',
                          label: 'forms.financialPlan.kindResult'.tr()),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? 'C'),
                  ),
                  const SizedBox(height: 8),
                  // Nível de Visualização (Rg_Nivel): Sintética × Analítica
                  SetesRadioGroup<String>(
                    label: 'forms.financialPlan.cluster'.tr(),
                    value: _cluster,
                    options: [
                      SetesRadioOption(
                          value: 'S',
                          label:
                              'forms.financialPlan.clusterSynthetic'.tr()),
                      SetesRadioOption(
                          value: 'A',
                          label: 'forms.financialPlan.clusterAnalytic'.tr()),
                    ],
                    onChanged: (v) => setState(() => _cluster = v ?? 'S'),
                  ),
                  const SizedBox(height: 8),
                  SetesCheckbox(
                    label: 'forms.financialPlan.active'.tr(),
                    value: _active,
                    onChanged: (checked) =>
                        setState(() => _active = checked ?? true),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
