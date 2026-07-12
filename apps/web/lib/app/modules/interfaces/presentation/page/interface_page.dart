import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/interface_datasource.dart';
import '../../domain/entity/interface_entity.dart';
import '../../domain/entity/privilege_entity.dart';
import '../bloc/interface_bloc.dart';

/// Tela de Interfaces — interface 'interfaces' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Pesquisa ↔ formulário orquestrados pelo
/// InterfaceBloc; a página só traduz estados em widgets da fábrica.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código da interface gerado pelo backend (MAX+1 — decisão do Valdo
/// 2026-07-11): campo readOnly, vazio na inclusão e preenchido na edição.
/// A tela também gerencia os privilégios da interface
/// (tb_interface_has_privilege) via checkboxes: labels = description da
/// tb_privilege direto do banco (sem tradução); os ids selecionados vivem
/// no ESTADO DA PÁGINA (`Set<int>`), como o padrão de lookup — nunca nos
/// values do onSave da fábrica.
class InterfacePage extends StatefulWidget {
  const InterfacePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<InterfacePage> createState() => _InterfacePageState();
}

class _InterfacePageState extends State<InterfacePage> with FieldConfigLoader {
  late final InterfaceBloc _bloc;
  late final InterfaceDatasource _datasource;

  /// Lista de apoio dos checkboxes (tb_privilege) — carregada uma vez
  /// no initState via datasource (mesmo padrão dos lookups FK).
  List<PrivilegeEntity> _privileges = [];

  /// Privilégios selecionados no formulário — estado da página.
  Set<int> _selectedPrivilegeIds = {};

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<InterfaceBloc>()..add(const InterfaceListRequested(''));
    _datasource = Modular.get<InterfaceDatasource>();
    _loadPrivileges();
    loadFieldConfig('interfaces'); // engine de campos configuráveis (decisão 7)
  }

  Future<void> _loadPrivileges() async {
    try {
      final privileges = await _datasource.getPrivileges();
      if (mounted) setState(() => _privileges = privileges);
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: SetesText(failure.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: SetesText('register.error'.tr())));
      }
    }
  }

  void _openNew() {
    setState(() => _selectedPrivilegeIds = {});
    _bloc.add(const InterfaceNewPressed());
  }

  void _openEdit(InterfaceEntity entity) {
    setState(() => _selectedPrivilegeIds = entity.privilegeIds.toSet());
    _bloc.add(InterfaceEditPressed(entity));
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  String? _nullIfEmpty(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Seção de privilégios renderizada via [RegisterFormPage.extraChildren]:
  /// checkboxes fora do Tab (contrato visual, item 8).
  List<Widget> _buildPrivilegesSection() => [
        SetesText(
          'forms.interface.privileges'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ExcludeFocusTraversal(
          child: Column(
            children: [
              for (final privilege in _privileges)
                SetesCheckbox(
                  label: privilege.description ?? '',
                  value: _selectedPrivilegeIds.contains(privilege.id),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selectedPrivilegeIds.add(privilege.id);
                    } else {
                      _selectedPrivilegeIds.remove(privilege.id);
                    }
                  }),
                ),
            ],
          ),
        ),
      ];

  Widget _buildForm(InterfaceFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':           '${editing.id}',
              'description':  editing.description ?? '',
              'groupDefault': editing.groupDefault ?? '',
              'i18nKey':      editing.i18nKey ?? '',
              'kind':         editing.kind ?? '',
              'position':     editing.position ?? '',
            },
      fields: applyFieldConfig([
        // Código gerado pelo backend (MAX+1): sempre readOnly — vazio na
        // inclusão, preenchido na edição (decisão do Valdo 2026-07-11).
        RegisterField(
          name:     'id',
          label:    'forms.interface.code'.tr(),
          readOnly: true,
        ),
        RegisterField(
          name:      'description',
          label:     'forms.interface.description'.tr(),
          validator: _validateRequired,
        ),
        RegisterField(
          name:  'groupDefault',
          label: 'forms.interface.group'.tr(),
        ),
        RegisterField(
          name:  'i18nKey',
          label: 'forms.interface.i18nKey'.tr(),
        ),
        // kind e position são texto livre (decisão do Valdo 2026-07-11).
        RegisterField(
          name:  'kind',
          label: 'forms.interface.kind'.tr(),
        ),
        RegisterField(
          name:  'position',
          label: 'forms.interface.position'.tr(),
        ),
      ], fieldConfig),
      extraChildren: _buildPrivilegesSection(),
      onSave: (values) => _bloc.add(InterfaceSaveRequested(
        entity: InterfaceEntity(
          id:           creating ? 0 : editing.id, // ignorado no POST
          description:  values['description'] ?? '',
          groupDefault: _nullIfEmpty(values['groupDefault']),
          i18nKey:      _nullIfEmpty(values['i18nKey']),
          kind:         _nullIfEmpty(values['kind']),
          position:     _nullIfEmpty(values['position']),
          privilegeIds: _selectedPrivilegeIds.toList()..sort(),
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const InterfaceBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(InterfaceDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(InterfaceListState state) =>
      RegisterSearchPage<InterfaceEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (e) => '${e.id}',
        rowBuilder: (e) => [
          e.description ?? '',
          if ((e.groupDefault ?? '').isNotEmpty) e.groupDefault!,
          if ((e.i18nKey ?? '').isNotEmpty) e.i18nKey!,
        ],
        onFilterChanged: (filter) => _bloc.add(InterfaceListRequested(filter)),
        onNew: _openNew,
        onView: _openEdit,
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<InterfaceBloc, InterfaceState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is InterfaceActionSuccess ||
            current is InterfaceActionFailure,
        listener: (context, state) {
          final message = state is InterfaceActionSuccess
              ? state.messageKey.tr()
              : (state as InterfaceActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is InterfaceListState || current is InterfaceFormState,
        builder: (context, state) => switch (state) {
          InterfaceFormState() => _buildForm(state),
          InterfaceListState() => _buildSearch(state),
          _ => _buildSearch(const InterfaceListState(loading: true)),
        },
      );
}
