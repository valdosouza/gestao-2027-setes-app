import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/privilege_entity.dart';
import '../bloc/privilege_bloc.dart';

/// Tela de Privilégios — interface 'privileges' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Pesquisa ↔ formulário orquestrados pelo
/// PrivilegeBloc; a página só traduz estados em widgets da fábrica.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código do privilégio gerado pelo backend (MAX+1 — precedente do cadastro
/// de Interfaces, decisão do Valdo 2026-07-11): campo readOnly, vazio na
/// inclusão e preenchido na edição. As descriptions alimentam os checkboxes
/// da tela de Interfaces (tb_interface_has_privilege) — direto do banco,
/// sem tradução.
class PrivilegePage extends StatefulWidget {
  const PrivilegePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<PrivilegePage> createState() => _PrivilegePageState();
}

class _PrivilegePageState extends State<PrivilegePage> {
  late final PrivilegeBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<PrivilegeBloc>()..add(const PrivilegeListRequested(''));
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  Widget _buildForm(PrivilegeFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {'id': '${editing.id}', 'description': editing.description ?? ''},
      fields: [
        // Código gerado pelo backend (MAX+1): sempre readOnly — vazio na
        // inclusão, preenchido na edição (decisão do Valdo 2026-07-11).
        RegisterField(
          name:     'id',
          label:    'forms.privilege.code'.tr(),
          readOnly: true,
        ),
        RegisterField(
          name:      'description',
          label:     'forms.privilege.description'.tr(),
          validator: _validateRequired,
        ),
      ],
      onSave: (values) => _bloc.add(PrivilegeSaveRequested(
        privilege: PrivilegeEntity(
          id:          creating ? 0 : editing.id, // ignorado no POST
          description: values['description'] ?? '',
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const PrivilegeBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(PrivilegeDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(PrivilegeListState state) =>
      RegisterSearchPage<PrivilegeEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (p) => '${p.id}',
        rowBuilder: (p) => [p.description ?? ''],
        onFilterChanged: (filter) => _bloc.add(PrivilegeListRequested(filter)),
        onNew: () => _bloc.add(const PrivilegeNewPressed()),
        onView: (p) => _bloc.add(PrivilegeEditPressed(p)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PrivilegeBloc, PrivilegeState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is PrivilegeActionSuccess ||
            current is PrivilegeActionFailure,
        listener: (context, state) {
          final message = state is PrivilegeActionSuccess
              ? state.messageKey.tr()
              : (state as PrivilegeActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is PrivilegeListState || current is PrivilegeFormState,
        builder: (context, state) => switch (state) {
          PrivilegeFormState() => _buildForm(state),
          PrivilegeListState() => _buildSearch(state),
          _ => _buildSearch(const PrivilegeListState(loading: true)),
        },
      );
}
