import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/cfop_entity.dart';
import '../bloc/cfop_bloc.dart';

/// Tela de CFOP — interface 'cfop' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Referência fiscal do catálogo CENTRAL —
/// acesso: role='super' (guard no backend).
///
/// O CÓDIGO É O PRÓPRIO id (string, digitado pelo usuário — padrão de
/// código externo, precedente País/BACEN): editável só na inclusão, 409 se
/// já existir (mesmo excluído), imutável na edição. Sentido (E/S) e Alçada
/// (E/N/X) são radios (reg_cfop.pas); Aplicação é texto longo (maxLines).
class CfopPage extends StatefulWidget {
  const CfopPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<CfopPage> createState() => _CfopPageState();
}

class _CfopPageState extends State<CfopPage> with FieldConfigLoader {
  late final CfopBloc _bloc;

  /// Acesso ao estado da fábrica: ancora o fields[] do servidor no campo
  /// (showServerFieldError — Framework de Mensagens, Onda B).
  final _formPageKey = GlobalKey<RegisterFormPageState>();

  /// Radios/checkbox e Aplicação — estado da página (extraChildren fica
  /// fora dos values da fábrica).
  String? _way;
  String? _jurisdiction;
  bool _active = true;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CfopBloc>()..add(const CfopListRequested(''));
    loadFieldConfig('cfop'); // engine de campos configuráveis (decisão 7)
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _openNew() {
    setState(() {
      _way = 'S'; // predominância: CFOPs de saída (emissão de nota)
      _jurisdiction = 'E';
      _active = true;
      _note.text = '';
    });
    _bloc.add(const CfopNewPressed());
  }

  void _openEdit(CfopEntity entity) {
    setState(() {
      _way = entity.way;
      _jurisdiction = entity.jurisdiction;
      _active = entity.active;
      _note.text = entity.note ?? '';
    });
    _bloc.add(CfopEditPressed(entity));
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  String? _validateCode(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'register.required'.tr();
    if (!RegExp(r'^[0-9][0-9.]{0,9}$').hasMatch(t)) {
      return 'forms.cfop.codeInvalid'.tr();
    }
    return null;
  }

  String? _nullIfEmpty(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String? _validateOptionalInt(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    return int.tryParse(t) == null ? 'register.invalidNumber'.tr() : null;
  }

  List<Widget> _buildExtraFields() => [
        ExcludeFocusTraversal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sentido (Rgp_Sentido do reg_cfop): Entrada × Saída
              SetesRadioGroup<String>(
                label: 'forms.cfop.way'.tr(),
                value: _way,
                options: [
                  SetesRadioOption(
                      value: 'E', label: 'forms.cfop.wayIn'.tr()),
                  SetesRadioOption(
                      value: 'S', label: 'forms.cfop.wayOut'.tr()),
                ],
                onChanged: (v) => setState(() => _way = v),
              ),
              const SizedBox(height: 8),
              // Alçada (Rgp_Alcada): Estadual × Nacional × Exterior
              SetesRadioGroup<String>(
                label: 'forms.cfop.jurisdiction'.tr(),
                value: _jurisdiction,
                options: [
                  SetesRadioOption(
                      value: 'E',
                      label: 'forms.cfop.jurisdictionState'.tr()),
                  SetesRadioOption(
                      value: 'N',
                      label: 'forms.cfop.jurisdictionNational'.tr()),
                  SetesRadioOption(
                      value: 'X',
                      label: 'forms.cfop.jurisdictionForeign'.tr()),
                ],
                onChanged: (v) => setState(() => _jurisdiction = v),
              ),
              const SizedBox(height: 8),
              // Aplicação (mmoAplicacao): texto longo
              SetesTextField(
                label: 'forms.cfop.note'.tr(),
                controller: _note,
                maxLines: 5,
              ),
              const SizedBox(height: 8),
              SetesCheckbox(
                label: 'forms.cfop.active'.tr(),
                value: _active,
                onChanged: (checked) =>
                    setState(() => _active = checked ?? true),
              ),
            ],
          ),
        ),
      ];

  Widget _buildForm(CfopFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      key: _formPageKey,
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':          editing.id,
              'description': editing.description ?? '',
              'concise':     editing.concise ?? '',
              'register':    editing.register?.toString() ?? '',
            },
      fields: applyFieldConfig([
        // Código = o PRÓPRIO CFOP, digitado na inclusão (padrão código
        // externo — precedente País/BACEN); imutável na edição.
        RegisterField(
          name:         'id',
          label:        'forms.cfop.code'.tr(),
          readOnly:     !creating,
          keyboardType: TextInputType.number,
          validator:    creating ? _validateCode : null,
        ),
        RegisterField(
          name:      'description',
          label:     'forms.cfop.description'.tr(),
          validator: _validateRequired,
        ),
        RegisterField(
          name:  'concise',
          label: 'forms.cfop.concise'.tr(),
        ),
        RegisterField(
          name:         'register',
          label:        'forms.cfop.register'.tr(),
          keyboardType: TextInputType.number,
          validator:    _validateOptionalInt,
        ),
      ], fieldConfig),
      extraChildren: _buildExtraFields(),
      onSave: (values) => _bloc.add(CfopSaveRequested(
        cfop: CfopEntity(
          id:           creating ? (values['id'] ?? '').trim() : editing.id,
          description:  values['description'] ?? '',
          concise:      _nullIfEmpty(values['concise']),
          register:     int.tryParse(values['register']?.trim() ?? ''),
          way:          _way,
          jurisdiction: _jurisdiction,
          note:         _note.text,
          active:       _active,
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const CfopBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(CfopDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(CfopListState state) => RegisterSearchPage<CfopEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'cfop',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (c) => c.id,
        rowBuilder: (c) => [
          c.description ?? '',
          if ((c.concise ?? '').isNotEmpty) c.concise!,
          c.way == 'E' ? 'forms.cfop.wayIn'.tr() : 'forms.cfop.wayOut'.tr(),
        ],
        onFilterChanged: (filter) => _bloc.add(CfopListRequested(filter)),
        onNew: _openNew,
        onView: _openEdit,
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<CfopBloc, CfopState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CfopActionSuccess || current is CfopActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado.
        listener: (context, state) {
          if (state is CfopActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as CfopActionFailure).failure;
          final form = _formPageKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is CfopListState || current is CfopFormState,
        builder: (context, state) => switch (state) {
          CfopFormState() => _buildForm(state),
          CfopListState() => _buildSearch(state),
          _ => _buildSearch(const CfopListState(loading: true)),
        },
      );
}
