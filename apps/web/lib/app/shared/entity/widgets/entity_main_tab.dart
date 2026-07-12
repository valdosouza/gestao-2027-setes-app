import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../domain/object_entity_fiscal.dart';
import 'entity_date.dart';

/// Aba "Principal" da cadeia de entidade fiscal — COMPARTILHADA entre
/// Institution/Customer/Provider/Collaborator/Bank (skill
/// cadastro-entidade-fiscal.md). Contrato de genericidade: recebe [value] +
/// [onChanged] tipados em shared/entity/domain — NUNCA importa módulo.
///
/// Campos de tb_entity + toggle PF/PJ que alterna tb_person × tb_company.
/// Trocar o toggle NÃO apaga o que foi digitado no outro tipo (o draft
/// preserva as duas fatias; só a do personType atual vai no salvar).
class EntityMainTab extends StatefulWidget {
  const EntityMainTab({required this.value, required this.onChanged, super.key});

  final ObjectEntityFiscal value;
  final ValueChanged<ObjectEntityFiscal> onChanged;

  @override
  State<EntityMainTab> createState() => _EntityMainTabState();
}

class _EntityMainTabState extends State<EntityMainTab> {
  late final TextEditingController _nameCompany;
  late final TextEditingController _nickTrade;
  late final TextEditingController _aniversary;
  late final TextEditingController _cpf;
  late final TextEditingController _rg;
  late final TextEditingController _birthday;
  late final TextEditingController _cnpj;
  late final TextEditingController _ie;
  late final TextEditingController _im;
  late final TextEditingController _dtFoundation;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _nameCompany  = TextEditingController(text: v.nameCompany);
    _nickTrade    = TextEditingController(text: v.nickTrade);
    _aniversary   = TextEditingController(text: isoDateToDisplay(v.aniversary));
    _cpf          = TextEditingController(text: v.person?.cpf ?? '');
    _rg           = TextEditingController(text: v.person?.rg ?? '');
    _birthday     = TextEditingController(text: isoDateToDisplay(v.person?.birthday));
    _cnpj         = TextEditingController(text: v.company?.cnpj ?? '');
    _ie           = TextEditingController(text: v.company?.ie ?? '');
    _im           = TextEditingController(text: v.company?.im ?? '');
    _dtFoundation = TextEditingController(text: isoDateToDisplay(v.company?.dtFoundation));
  }

  @override
  void dispose() {
    for (final c in [
      _nameCompany, _nickTrade, _aniversary, _cpf, _rg, _birthday,
      _cnpj, _ie, _im, _dtFoundation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  PersonData get _person => widget.value.person ?? const PersonData();
  CompanyData get _company => widget.value.company ?? const CompanyData();

  void _emit(ObjectEntityFiscal updated) => widget.onChanged(updated);

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  @override
  Widget build(BuildContext context) {
    final isPerson = widget.value.personType == 'F';

    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis, na ordem declarada; toggle PF/PJ fica fora da sequência.
    var order = 0;
    Widget field(Widget child) {
      final wrapped = FocusTraversalOrder(
        order: NumericFocusOrder((order++).toDouble()),
        child: child,
      );
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: wrapped);
    }

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            field(SetesTextField(
              label: 'forms.entity.nameCompany'.tr(),
              controller: _nameCompany,
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: _validateRequired,
              onChanged: (t) => _emit(widget.value.copyWith(nameCompany: t)),
            )),
            field(SetesTextField(
              label: 'forms.entity.nickTrade'.tr(),
              controller: _nickTrade,
              textInputAction: TextInputAction.next,
              validator: _validateRequired,
              onChanged: (t) => _emit(widget.value.copyWith(nickTrade: t)),
            )),
            field(SetesTextField(
              label: 'forms.entity.aniversary'.tr(),
              hint: 'register.dateHint'.tr(),
              controller: _aniversary,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.next,
              validator: validateOptionalDate,
              onChanged: (t) => _emit(widget.value
                  .copyWith(aniversary: () => displayDateToIso(t))),
            )),
            // Toggle PF/PJ (fora da sequência de Tab)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ExcludeFocusTraversal(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'F',
                          label: SetesText('forms.entity.personF'.tr())),
                      ButtonSegment(
                          value: 'J',
                          label: SetesText('forms.entity.personJ'.tr())),
                    ],
                    selected: {widget.value.personType},
                    onSelectionChanged: (selection) => _emit(
                        widget.value.copyWith(personType: selection.first)),
                  ),
                ),
              ),
            ),
            if (isPerson) ...[
              field(SetesTextField(
                label: 'forms.entity.cpf'.tr(),
                controller: _cpf,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateRequired,
                onChanged: (t) => _emit(widget.value
                    .copyWith(person: _person.copyWith(cpf: t.trim()))),
              )),
              field(SetesTextField(
                label: 'forms.entity.rg'.tr(),
                controller: _rg,
                textInputAction: TextInputAction.next,
                onChanged: (t) => _emit(
                    widget.value.copyWith(person: _person.copyWith(rg: t))),
              )),
              field(SetesTextField(
                label: 'forms.entity.birthday'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _birthday,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                validator: validateOptionalDate,
                onChanged: (t) => _emit(widget.value.copyWith(
                    person: _person.copyWith(
                        birthday: () => displayDateToIso(t)))),
              )),
            ] else ...[
              field(SetesTextField(
                label: 'forms.entity.cnpj'.tr(),
                controller: _cnpj,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateRequired,
                onChanged: (t) => _emit(widget.value
                    .copyWith(company: _company.copyWith(cnpj: t.trim()))),
              )),
              field(SetesTextField(
                label: 'forms.entity.ie'.tr(),
                controller: _ie,
                textInputAction: TextInputAction.next,
                onChanged: (t) => _emit(
                    widget.value.copyWith(company: _company.copyWith(ie: t))),
              )),
              field(SetesTextField(
                label: 'forms.entity.im'.tr(),
                controller: _im,
                textInputAction: TextInputAction.next,
                onChanged: (t) => _emit(
                    widget.value.copyWith(company: _company.copyWith(im: t))),
              )),
              field(SetesTextField(
                label: 'forms.entity.dtFoundation'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtFoundation,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                validator: validateOptionalDate,
                onChanged: (t) => _emit(widget.value.copyWith(
                    company: _company.copyWith(
                        dtFoundation: () => displayDateToIso(t)))),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
