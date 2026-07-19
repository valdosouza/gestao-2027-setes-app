import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../domain/entity/category_entity.dart';
import '../bloc/category_bloc.dart';

/// Tela de Categorias de produtos e serviços — interface 'categories',
/// cadastro em ÁRVORE (porta do Delphi reg_category.pas; decisões do Valdo
/// 2026-07-18). FOGE do molde lista+form: DUAS árvores em abas
/// (Produtos × Serviços), FAB = novo NÍVEL raiz, ação "+" no nó = novo
/// SUBNÍVEL, clique no nó = edição. Mover de pai é feito na edição (lookup
/// do nível superior — a API recalcula o posit_level da subárvore);
/// excluir com subníveis é bloqueado pela API (409 HAS_CHILDREN vira
/// dialog de validação via ponte de feedback — Framework de Mensagens).
class CategoryPage extends StatefulWidget {
  const CategoryPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  late final CategoryBloc _bloc;
  late final TabController _tabs;

  /// Acesso ao estado do form montado: ancora o fields[] do servidor no
  /// campo (Framework de Mensagens — padrão form_pendency, Onda B).
  final _formKey = GlobalKey<_CategoryFormViewState>();

  /// Última árvore carregada — alimenta o lookup de "nível superior" do
  /// form (mover de pai) sem nova consulta.
  List<CategoryEntity> _lastItems = const [];

  static const _kinds = ['P', 'S'];

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CategoryBloc>()..add(const CategoryTreeRequested('P'));
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        _bloc.add(CategoryTreeRequested(_kinds[_tabs.index]));
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Engrenagem padrão da lista (Framework de Configurações, decisão 11) —
  /// replicada manualmente porque a tela de árvore não usa a fábrica.
  void _openConfigs() {
    Modular.to.navigate('/home/interface-configs/', arguments: {
      'title': trCatalog('interface-configs', 'Interface Configs',
          prefix: 'menu.interfaces'),
      'moduleKey': 'categories',
      'returnTo': Modular.to.path,
    });
  }

  // -------------------------------------------------------------------
  // Árvore
  // -------------------------------------------------------------------

  /// Monta os nós a partir da lista ordenada por posit_level.
  List<SetesTreeNode<CategoryEntity>> _buildNodes(List<CategoryEntity> items) {
    final byParent = <int?, List<CategoryEntity>>{};
    for (final item in items) {
      byParent.putIfAbsent(item.parentId, () => []).add(item);
    }
    SetesTreeNode<CategoryEntity> node(CategoryEntity item) => SetesTreeNode(
          id: item.id,
          label: item.description ?? '',
          subtitle: item.active ? null : 'forms.category.inactiveRow'.tr(),
          data: item,
          children: [for (final c in byParent[item.id] ?? []) node(c)],
        );
    return [for (final root in byParent[null] ?? []) node(root)];
  }

  Widget _buildTree(CategoryTreeState state) {
    _lastItems = state.items;
    if (_tabs.index != _kinds.indexOf(state.kind)) {
      _tabs.index = _kinds.indexOf(state.kind);
    }
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
      // FAB = novo NÍVEL raiz da árvore ativa (Delphi: opção "Nível")
      floatingActionButton: FloatingActionButton(
        tooltip: 'forms.category.newRoot'.tr(),
        onPressed: () => _bloc.add(const CategoryNewPressed()),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Abas no CORPO (mesmo padrão das abas do form de Clientes):
          // sobre a superfície as cores do tema têm contraste — no bottom
          // da AppBar elas sumiam no fundo primário (feedback do Valdo).
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(
                icon: const Icon(Icons.inventory_2_outlined, size: 20),
                text: 'forms.category.tabProducts'.tr(),
              ),
              Tab(
                icon: const Icon(Icons.handyman_outlined, size: 20),
                text: 'forms.category.tabServices'.tr(),
              ),
            ],
          ),
          Expanded(
            child: state.loading
                ? const SetesCircularProgressIndicator()
                : SetesTreeView<CategoryEntity>(
                    nodes: _buildNodes(state.items),
                    emptyText: 'register.emptyList'.tr(),
                    onTap: (item) => _bloc.add(CategoryEditPressed(item)),
                    // Ação "+" no nó = novo SUBNÍVEL (Delphi: "SubNível")
                    onAddChild: (item) =>
                        _bloc.add(CategoryNewPressed(parent: item)),
                    addChildTooltip: 'forms.category.newChild'.tr(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(CategoryFormState state) => _CategoryFormView(
        key: _formKey,
        title: widget.title,
        state: state,
        items: _lastItems,
        onSave: (category, creating) => _bloc
            .add(CategorySaveRequested(category: category, creating: creating)),
        onBack: () => _bloc.add(const CategoryBackToTreePressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(CategoryDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CategoryBloc, CategoryState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CategoryActionSuccess ||
            current is CategoryActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha (inclusive 409 HAS_CHILDREN / TREE_CYCLE, mensagem da API) =
        // dialog, com fields[] ancorado no campo quando o form está montado.
        listener: (context, state) {
          if (state is CategoryActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as CategoryActionFailure).failure;
          final form = _formKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is CategoryTreeState || current is CategoryFormState,
        builder: (context, state) => switch (state) {
          CategoryFormState() => _buildForm(state),
          CategoryTreeState() => _buildTree(state),
          _ => _buildTree(const CategoryTreeState(kind: 'P', loading: true)),
        },
      );
}

/// Form da categoria (SetesFormShell): descrição + nível superior (lookup
/// da MESMA árvore — trocar o pai = mover, a API recalcula a subárvore) +
/// ativo. kind vem da aba (imutável); posição é calculada pela API.
class _CategoryFormView extends StatefulWidget {
  const _CategoryFormView({
    required this.title,
    required this.state,
    required this.items,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final CategoryFormState state;
  final List<CategoryEntity> items;
  final void Function(CategoryEntity category, bool creating) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_CategoryFormView> createState() => _CategoryFormViewState();
}

class _CategoryFormViewState extends State<_CategoryFormView> {
  late final TextEditingController _description;
  final _descriptionFocus = FocusNode();
  final _descriptionKey = GlobalKey<FormFieldState<String>>();
  int? _parentId;
  String? _parentName;
  late bool _active;

  CategoryEntity? get _editing => widget.state.editing;
  bool get _creating => _editing == null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _description = TextEditingController(text: editing?.description ?? '');
    _active = editing?.active ?? true;
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
    _descriptionFocus.dispose();
    super.dispose();
  }

  String? _nameOf(int? id) {
    if (id == null) return null;
    for (final item in widget.items) {
      if (item.id == id) return item.description;
    }
    return null;
  }

  /// Regra local do campo (mesma do validator inline do SetesTextField).
  String? _validateDescription() => _description.text.trim().isEmpty
      ? 'register.requiredField'.tr(args: ['forms.category.description'.tr()])
      : null;

  /// Campos participantes da validação, NA ORDEM da tela (R3) — também
  /// ancoram o fields[] do servidor ([showServerFieldError]).
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'description',
          validate: _validateDescription,
          focusNode: _descriptionFocus,
          fieldKey: _descriptionKey,
        ),
      ];

  /// fields[] do envelope 400/409 ancorado no campo — chamado pela página
  /// no listener do bloc via GlobalKey deste State.
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(context, failure, _pendencyFields);

  /// Candidatos a nível superior: a MESMA árvore, excluindo o próprio nó e
  /// seus descendentes (a API revalida — aqui é UX).
  Future<List<CategoryEntity>> _searchParents(String filter) async {
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
    final picked = await showSetesLookup<CategoryEntity>(
      context: context,
      title: 'forms.category.parent'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _searchParents,
      itemId: (c) => c.id,
      itemLabel: (c) => c.description ?? '',
    );
    if (picked != null) {
      setState(() {
        _parentId = picked.id;
        _parentName = picked.description;
      });
    }
  }

  /// UMA pendência por vez (R3): dialog da ponte → OK → foco no campo.
  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    widget.onSave(
      CategoryEntity(
        id:          _editing?.id ?? 0, // ignorado no POST
        description: _description.text.trim(),
        parentId:    _parentId,
        kind:        widget.state.kind,
        active:      _active,
      ),
      _creating,
    );
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4): Sim = excluir;
  /// Cancelar (ou fechar) = nada. Sem ação alternativa → sem botão Não.
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
    final kindLabel = widget.state.kind == 'S'
        ? 'forms.category.tabServices'.tr()
        : 'forms.category.tabProducts'.tr();
    return SetesFormShell(
      title: '${widget.title} · $kindLabel',
      saving: widget.state.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_creating) ...[
            SetesTextField(
              label: 'forms.category.code'.tr(),
              controller: TextEditingController(text: '${_editing!.id}'),
              readOnly: true,
            ),
            const SizedBox(height: 16),
          ],
          SetesTextField(
            label: 'forms.category.description'.tr(),
            controller: _description,
            autofocus: true,
            focusNode: _descriptionFocus,
            fieldKey: _descriptionKey,
            // marca SÓ este campo após o OK do dialog de pendência (R3)
            validator: (_) => _validateDescription(),
          ),
          const SizedBox(height: 16),
          // Nível superior (lookup da mesma árvore) — trocar = MOVER;
          // limpar = virar nível raiz.
          SetesLookupField(
            label: 'forms.category.parent'.tr(),
            display: _parentName ?? 'forms.category.rootLevel'.tr(),
            onSearch: _pickParent,
            onClear: () => setState(() {
              _parentId = null;
              _parentName = null;
            }),
          ),
          const SizedBox(height: 8),
          ExcludeFocusTraversal(
            child: SetesCheckbox(
              label: 'forms.category.active'.tr(),
              value: _active,
              onChanged: (checked) =>
                  setState(() => _active = checked ?? true),
            ),
          ),
        ],
      ),
    );
  }
}
