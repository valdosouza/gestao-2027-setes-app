import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_validators/setes_validators.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/icons/material_icon_names.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/module_entity.dart';
import '../bloc/module_bloc.dart';
import '../widget/module_interfaces_section.dart';

/// Tela de Módulos de Menu do cliente — interface 'modules', camada 2 do
/// menu (prompt_modulo_menus.md D1–D4, Valdo 2026-08-04). Tela do ADMIN
/// (adminGuard na API — D2); pesquisa ↔ formulário orquestrados pelo
/// ModuleBloc; a página só traduz estados em widgets da fábrica.
///
/// Código do módulo gerado pelo backend (MAX+1 — precedente de Privilégios):
/// campo readOnly, vazio na inclusão e preenchido na edição. A seção "Telas
/// do módulo" é o vínculo ORDENÁVEL (D3): a ordem visual É o array
/// interfaceIds enviado no salvar. Ícone por NOME Material (D4) com preview
/// ao lado do campo (fallback Icons.folder).
class ModulePage extends StatefulWidget {
  const ModulePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> with FieldConfigLoader {
  late final ModuleBloc _bloc;

  /// Acesso ao estado da fábrica: ancora o fields[] do servidor no campo
  /// (showServerFieldError — Framework de Mensagens, Onda B).
  final _formPageKey = GlobalKey<RegisterFormPageState>();

  /// Vínculo ordenável (D3) — estado da página, como o id de lookup FK:
  /// nunca entra nos values do onSave da fábrica.
  List<int> _interfaceIds = const [];

  /// Elegíveis do form corrente (rótulos p/ ancorar o 422 do salvar).
  List<ModuleInterfaceOption> _options = const [];

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ModuleBloc>()..add(const ModuleListRequested(''));
    loadFieldConfig('modules'); // engine de campos configuráveis (decisão 7)
  }

  /// 422 de interface não elegível (contrato: fields[0] =
  /// `{field: 'interfaceIds', message: '<id>'}`): ancora na SEÇÃO de telas — dialog
  /// com o rótulo da tela apontada (nunca o "Validação falhou" genérico).
  Future<void> _handleFailure(ModuleActionFailure state) async {
    final failure = state.failure;
    final serverField =
        failure.fields.isNotEmpty ? failure.fields.first : null;
    if (serverField != null && serverField.field == 'interfaceIds') {
      final id = int.tryParse(serverField.message);
      final label = id == null
          ? serverField.message
          : moduleInterfaceLabel(_options, id);
      await showValidationFeedback(
          context, 'forms.module.screenNotEligible'.tr(args: [label]));
      return;
    }
    final form = _formPageKey.currentState;
    if (failure.fields.isNotEmpty && form != null) {
      await form.showServerFieldError(failure);
    } else {
      await showFailureFeedback(context, failure);
    }
  }

  Widget _buildForm(ModuleFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    _options = state.options; // rótulos p/ ancorar o 422 do salvar
    return RegisterFormPage(
      key: _formPageKey,
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id': '${editing.id}',
              'description': editing.description ?? '',
              'position':
                  editing.position == null ? '' : '${editing.position}',
              'imageIcon': editing.imageIcon ?? '',
            },
      fields: applyFieldConfig([
        // Código gerado pelo backend (MAX+1): sempre readOnly — vazio na
        // inclusão, preenchido na edição (precedente de Privilégios).
        RegisterField(
          name:     'id',
          label:    'forms.module.code'.tr(),
          readOnly: true,
        ),
        // Catálogo tb_interface_has_field (seed sql/26) × DTO Zod
        // (modules.dto.ts): description obrigatória max 100; position int
        // opcional; image_icon string opcional max 50.
        RegisterField(
          name:      'description',
          label:     'forms.module.description'.tr(),
          validator: SetesValidators.compose([
            SetesValidators.required(),
            SetesValidators.maxLength(100),
          ]),
        ),
        RegisterField(
          name:         'position',
          label:        'forms.module.position'.tr(),
          hint:         'forms.module.positionHint'.tr(),
          keyboardType: TextInputType.number,
          validator:    SetesValidators.onlyDigits(),
        ),
        // Ícone por NOME Material (D4) com preview ao vivo ao lado do
        // campo: nome conhecido = o próprio ícone; sem match = Icons.folder.
        RegisterField(
          name:      'imageIcon',
          label:     'forms.module.icon'.tr(),
          hint:      'forms.module.iconHint'.tr(),
          validator: SetesValidators.maxLength(50),
          trailingBuilder: (context, value) => Icon(
            materialIconByName(value) ?? Icons.folder,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ], fieldConfig),
      extraChildren: [
        ModuleInterfacesSection(
          options: state.options,
          interfaceIds: _interfaceIds,
          enabled: !state.saving,
          onChanged: (ids) => setState(() => _interfaceIds = ids),
        ),
      ],
      onSave: (values) => _bloc.add(ModuleSaveRequested(
        module: ModuleEntity(
          id:          creating ? 0 : editing.id, // ignorado no POST
          description: values['description'] ?? '',
          // Vazia = fim da fila (a API resolve MAX+1 da ordem — contrato).
          position:  int.tryParse(values['position'] ?? ''),
          imageIcon: (values['imageIcon'] ?? '').isEmpty
              ? null
              : values['imageIcon'],
          interfaceIds: _interfaceIds,
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const ModuleBackToListPressed()),
      onDelete:
          creating ? null : () => _bloc.add(ModuleDeleteRequested(editing.id)),
      canDelete: !creating,
      // Exclusão graciosa (contrato do DELETE): avisa que as telas voltam
      // aos grupos padrão do menu.
      deleteConfirmMessage: 'forms.module.deleteWarning'.tr(),
    );
  }

  Widget _buildSearch(ModuleListState state) =>
      RegisterSearchPage<ModuleEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'modules',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (m) => '${m.id}',
        rowBuilder: (m) => [
          m.description ?? '',
          'forms.module.linkedCount'
              .tr(args: ['${m.interfaceIds.length}']),
        ],
        // Paginação (D1/D3): metadados do estado montam a barra da fábrica;
        // filtro novo volta à página 1; troca de tamanho recarrega na 1
        // (a persistência da escolha é da fábrica — D4).
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(ModuleListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(ModuleListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(ModuleListRequested(filter)),
        // O vínculo ordenável é estado da PÁGINA: inicializa AQUI, na
        // abertura do form (recarga por falha de salvar não clobbera a
        // edição em curso da seção).
        onNew: () {
          _interfaceIds = const [];
          _bloc.add(const ModuleNewPressed());
        },
        onView: (m) {
          _interfaceIds = List<int>.of(m.interfaceIds);
          _bloc.add(ModuleEditPressed(m));
        },
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<ModuleBloc, ModuleState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is ModuleActionSuccess || current is ModuleActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com o 422 de interfaceIds ancorado na seção de
        // telas e os demais fields[] no campo do formulário.
        listener: (context, state) {
          if (state is ModuleActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          _handleFailure(state as ModuleActionFailure);
        },
        buildWhen: (_, current) =>
            current is ModuleListState || current is ModuleFormState,
        builder: (context, state) => switch (state) {
          ModuleFormState() => _buildForm(state),
          ModuleListState() => _buildSearch(state),
          _ => _buildSearch(const ModuleListState(loading: true)),
        },
      );
}
