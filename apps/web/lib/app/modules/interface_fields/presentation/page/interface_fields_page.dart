import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../bloc/interface_fields_bloc.dart';

/// Painel Sistema/Admin de campos configuráveis — interface
/// 'interface-fields' (decisões 6 e 9 da Fase 2).
///
/// Vitrine: TODAS as interfaces do produto (estratégia comercial), com
/// filtro por nome/módulo; as adquiridas abrem a lista de campos. A lista
/// mostra TODOS os campos, inclusive os travados (obrigatoriedade técnica —
/// cadeado); no dialog o cliente edita caption/required/mask (o required
/// técnico aparece desabilitado — cliente só APERTA, decisão 2).
class InterfaceFieldsPage extends StatefulWidget {
  const InterfaceFieldsPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<InterfaceFieldsPage> createState() => _InterfaceFieldsPageState();
}

class _InterfaceFieldsPageState extends State<InterfaceFieldsPage> {
  late final InterfaceFieldsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<InterfaceFieldsBloc>()
      ..add(const InterfaceFieldsVitrineRequested(''));
  }

  void _openInterface(InterfaceVitrineEntity iface) {
    if (!iface.acquired) {
      // Vitrine comercial (decisão 6): mostra que existe, instiga a compra.
      // Bloqueio corrigível pelo usuário → dialog de validação via ponte.
      showValidationFeedback(
          context, 'forms.interfaceFields.notAcquired'.tr());
      return;
    }
    _bloc.add(InterfaceFieldsInterfaceOpened(iface));
  }

  Future<void> _editField(FieldConfigEntity field) async {
    final result = await showDialog<InterfaceFieldsFieldSaveRequested>(
      context: context,
      builder: (_) => _FieldConfigDialog(field: field),
    );
    if (result != null) _bloc.add(result);
  }

  Widget _buildVitrine(InterfaceFieldsVitrineState state) =>
      RegisterSearchPage<InterfaceVitrineEntity>(
        title: widget.title,
        items: state.items,
        loading: state.loading,
        avatarBuilder: (i) => '${i.id}',
        rowBuilder: (i) => [
          i.description ?? '',
          if ((i.moduleNames ?? '').isNotEmpty) i.moduleNames!,
          i.acquired
              ? 'forms.interfaceFields.acquired'.tr()
              : 'forms.interfaceFields.available'.tr(),
        ],
        onFilterChanged: (filter) =>
            _bloc.add(InterfaceFieldsVitrineRequested(filter)),
        onView: _openInterface,
      );

  Widget _buildFields(InterfaceFieldsFieldsState state) => SetesFormShell(
        title: '${widget.title} · ${state.iface.description ?? ''}',
        saving: state.saving,
        onBack: () => _bloc.add(const InterfaceFieldsBackToVitrine()),
        child: state.loading
            ? const SetesCircularProgressIndicator()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.fields.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final field = state.fields[index];
                  final details = [
                    field.fieldName,
                    field.kind,
                    if (field.mask != null)
                      '${'forms.interfaceFields.mask'.tr()}: ${field.mask}',
                    if (field.required) 'forms.validation.required'.tr(),
                  ].join(' · ');
                  return SetesListTile(
                    leading: Icon(field.requiredTech
                        ? Icons.lock_outline
                        : (field.customized
                            ? Icons.tune
                            : Icons.settings_outlined)),
                    title: SetesText(field.caption ?? field.fieldNameCamel),
                    subtitle: SetesText(details),
                    onTap: () => _editField(field),
                  );
                },
              ),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<InterfaceFieldsBloc, InterfaceFieldsState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is InterfaceFieldsActionSuccess ||
            current is InterfaceFieldsActionFailure,
        // PONTE de feedback (Framework de Mensagens): sucesso = SnackBar
        // via ponte (R1); falha = dialog — a ponte deriva a natureza (R7).
        listener: (context, state) {
          if (state is InterfaceFieldsActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          showFailureFeedback(
              context, (state as InterfaceFieldsActionFailure).failure);
        },
        buildWhen: (_, current) =>
            current is InterfaceFieldsVitrineState ||
            current is InterfaceFieldsFieldsState,
        builder: (context, state) => switch (state) {
          InterfaceFieldsFieldsState() => _buildFields(state),
          InterfaceFieldsVitrineState() => _buildVitrine(state),
          _ => _buildVitrine(const InterfaceFieldsVitrineState(loading: true)),
        },
      );
}

/// Dialog de edição da config de UM campo (caption/required/mask —
/// decisão 3). required técnico aparece marcado e DESABILITADO (decisão 2).
class _FieldConfigDialog extends StatefulWidget {
  const _FieldConfigDialog({required this.field});

  final FieldConfigEntity field;

  @override
  State<_FieldConfigDialog> createState() => _FieldConfigDialogState();
}

class _FieldConfigDialogState extends State<_FieldConfigDialog> {
  late final TextEditingController _caption;
  late final TextEditingController _mask;
  late bool _required;

  final _captionFocus = FocusNode();
  final _captionKey = GlobalKey<FormFieldState<String>>();
  final _maskFocus = FocusNode();
  final _maskKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _caption  = TextEditingController(text: widget.field.caption ?? '');
    _mask     = TextEditingController(text: widget.field.mask ?? '');
    _required = widget.field.required;
  }

  @override
  void dispose() {
    _caption.dispose();
    _mask.dispose();
    _captionFocus.dispose();
    _maskFocus.dispose();
    super.dispose();
  }

  /// Baseline do DTO da API (fieldConfigDto): caption até 100 caracteres.
  String? _validateCaption() =>
      _caption.text.trim().length > 100
          ? 'forms.interfaceFields.captionTooLong'.tr()
          : null;

  /// Baseline do DTO (mask até 50) + semântica do setes_validators:
  /// # = dígito, A = letra, demais literais — máscara sem placeholder
  /// não formata nada (entrada inválida).
  String? _validateMask() {
    final mask = _mask.text.trim();
    if (mask.isEmpty) return null; // sem máscara = volta a herdar
    if (mask.length > 50 || !(mask.contains('#') || mask.contains('A'))) {
      return 'forms.interfaceFields.invalidMask'.tr();
    }
    return null;
  }

  /// Campos do dialog NA ORDEM da tela (R3 — uma pendência por vez).
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'fieldCaption',
          validate: _validateCaption,
          focusNode: _captionFocus,
          fieldKey: _captionKey,
        ),
        PendencyField(
          name: 'mask',
          validate: _validateMask,
          focusNode: _maskFocus,
          fieldKey: _maskKey,
        ),
      ];

  Future<void> _submit() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    if (!mounted) return;
    final field = widget.field;
    Navigator.of(context).pop(
      InterfaceFieldsFieldSaveRequested(
        fieldName: field.fieldName,
        caption: _caption.text.trim(),
        // required técnico não é config do cliente (a API rejeitaria
        // afrouxo; apertado só vale nos campos liberados)
        required: !field.requiredTech && _required,
        mask: _mask.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    return AlertDialog(
      title: SetesText(field.fieldNameCamel),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SetesTextField(
              label: 'forms.interfaceFields.caption'.tr(),
              hint: 'forms.interfaceFields.captionHint'.tr(),
              controller: _caption,
              autofocus: true,
              focusNode: _captionFocus,
              fieldKey: _captionKey,
              validator: (_) => _validateCaption(),
            ),
            const SizedBox(height: 16),
            SetesTextField(
              label: 'forms.interfaceFields.mask'.tr(),
              hint: 'forms.interfaceFields.maskHint'.tr(),
              controller: _mask,
              focusNode: _maskFocus,
              fieldKey: _maskKey,
              validator: (_) => _validateMask(),
            ),
            const SizedBox(height: 8),
            SetesCheckbox(
              label: field.requiredTech
                  ? 'forms.interfaceFields.requiredTech'.tr()
                  : 'forms.interfaceFields.required'.tr(),
              value: _required,
              enabled: !field.requiredTech, // cliente só aperta (decisão 2)
              onChanged: (checked) =>
                  setState(() => _required = checked ?? false),
            ),
          ],
        ),
      ),
      actions: [
        SetesButton(
          label: 'register.cancel'.tr(),
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SetesButton(
          label: 'register.save'.tr(),
          kind: SetesButtonKind.text,
          onPressed: _submit,
        ),
      ],
    );
  }
}
