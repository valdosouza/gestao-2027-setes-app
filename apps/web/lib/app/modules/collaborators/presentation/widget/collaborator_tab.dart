import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../domain/entity/object_collaborator.dart';

/// Aba "Colaborador" — campos específicos de tb_collaborator (skill
/// cadastro-entidade-fiscal.md; onda 2 da Entidade Única, decisão 16).
/// Mesmo contrato das demais abas: recebe `value` + `onChanged` e o draft
/// vive no bloc do módulo. Datas digitadas dd/mm/aaaa e trafegadas em ISO
/// (entity_date.dart, mesmo padrão do aniversário da aba Principal).
class CollaboratorTab extends StatefulWidget {
  const CollaboratorTab({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ObjectCollaborator value;
  final ValueChanged<ObjectCollaborator> onChanged;

  @override
  State<CollaboratorTab> createState() => _CollaboratorTabState();
}

class _CollaboratorTabState extends State<CollaboratorTab> {
  late final TextEditingController _dtAdmission;
  late final TextEditingController _dtResignation;
  late final TextEditingController _salary;
  late final TextEditingController _fathersName;
  late final TextEditingController _mothersName;
  late final TextEditingController _voteNumber;
  late final TextEditingController _voteZone;
  late final TextEditingController _voteSection;
  late final TextEditingController _militaryCertificate;
  late final TextEditingController _pis;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _dtAdmission   = TextEditingController(text: isoDateToDisplay(v.dtAdmission));
    _dtResignation =
        TextEditingController(text: isoDateToDisplay(v.dtResignation));
    _salary        = TextEditingController(text: _decimalToText(v.salary));
    _fathersName   = TextEditingController(text: v.fathersName ?? '');
    _mothersName   = TextEditingController(text: v.mothersName ?? '');
    _voteNumber    = TextEditingController(text: v.voteNumber ?? '');
    _voteZone      = TextEditingController(text: v.voteZone ?? '');
    _voteSection   = TextEditingController(text: v.voteSection ?? '');
    _militaryCertificate =
        TextEditingController(text: v.militaryCertificate ?? '');
    _pis           = TextEditingController(text: v.pis ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _dtAdmission, _dtResignation, _salary, _fathersName, _mothersName,
      _voteNumber, _voteZone, _voteSection, _militaryCertificate, _pis,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _decimalToText(double? value) =>
      value == null ? '' : value.toString();

  /// Aceita vírgula ou ponto; null se vazio/inválido.
  static double? _textToDecimal(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  String? _validateOptionalDecimal(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    return _textToDecimal(t) == null ? 'register.invalidNumber'.tr() : null;
  }

  void _emit(ObjectCollaborator updated) => widget.onChanged(updated);

  @override
  Widget build(BuildContext context) {
    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis; o checkbox fica fora da sequência.
    var order = 0;
    Widget field(Widget child) {
      final wrapped = FocusTraversalOrder(
        order: NumericFocusOrder((order++).toDouble()),
        child: child,
      );
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: wrapped);
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(SetesTextField(
            label: 'forms.collaborator.dtAdmission'.tr(),
            hint: 'register.dateHint'.tr(),
            controller: _dtAdmission,
            validator: validateOptionalDate,
            onChanged: (text) => _emit(widget.value
                .copyWith(dtAdmission: () => displayDateToIso(text))),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.dtResignation'.tr(),
            hint: 'register.dateHint'.tr(),
            controller: _dtResignation,
            validator: validateOptionalDate,
            onChanged: (text) => _emit(widget.value
                .copyWith(dtResignation: () => displayDateToIso(text))),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.salary'.tr(),
            controller: _salary,
            keyboardType: TextInputType.number,
            validator: _validateOptionalDecimal,
            onChanged: (text) => _emit(
                widget.value.copyWith(salary: () => _textToDecimal(text))),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.fathersName'.tr(),
            controller: _fathersName,
            onChanged: (text) =>
                _emit(widget.value.copyWith(fathersName: () => text)),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.mothersName'.tr(),
            controller: _mothersName,
            onChanged: (text) =>
                _emit(widget.value.copyWith(mothersName: () => text)),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.voteNumber'.tr(),
            controller: _voteNumber,
            onChanged: (text) =>
                _emit(widget.value.copyWith(voteNumber: () => text)),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.voteZone'.tr(),
            controller: _voteZone,
            onChanged: (text) =>
                _emit(widget.value.copyWith(voteZone: () => text)),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.voteSection'.tr(),
            controller: _voteSection,
            onChanged: (text) =>
                _emit(widget.value.copyWith(voteSection: () => text)),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.militaryCertificate'.tr(),
            controller: _militaryCertificate,
            onChanged: (text) =>
                _emit(widget.value.copyWith(militaryCertificate: () => text)),
          )),
          field(SetesTextField(
            label: 'forms.collaborator.pis'.tr(),
            controller: _pis,
            onChanged: (text) => _emit(widget.value.copyWith(pis: () => text)),
          )),
          ExcludeFocusTraversal(
            child: SetesCheckbox(
              label: 'forms.collaborator.active'.tr(),
              value: widget.value.active,
              onChanged: (v) =>
                  _emit(widget.value.copyWith(active: v ?? true)),
            ),
          ),
        ],
      ),
    );
  }
}
