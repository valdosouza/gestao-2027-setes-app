import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../feedback/feedback.dart';
import '../data/entity_by_document_datasource.dart';
import '../domain/object_entity_fiscal.dart';
import 'entity_date.dart';

/// Ganchos da mecânica UMA-PENDÊNCIA (R3) para os campos desta aba dentro
/// de um form COMPOSTO por abas: o dono do form (page do módulo) cria os
/// ganchos, monta seus PendencyFields com eles (foco + marca no campo certo
/// após trocar para esta aba) e repassa à aba via [EntityMainTab.hooks].
/// O dono é responsável por [dispose].
class EntityMainTabHooks {
  final nameCompanyFocus = FocusNode();
  final nickTradeFocus = FocusNode();
  final cpfFocus = FocusNode();
  final cnpjFocus = FocusNode();

  final nameCompanyKey = GlobalKey<FormFieldState<String>>();
  final nickTradeKey = GlobalKey<FormFieldState<String>>();
  final cpfKey = GlobalKey<FormFieldState<String>>();
  final cnpjKey = GlobalKey<FormFieldState<String>>();

  void dispose() {
    for (final node in [nameCompanyFocus, nickTradeFocus, cpfFocus, cnpjFocus]) {
      node.dispose();
    }
  }
}

/// Aba "Principal" da cadeia de entidade fiscal — COMPARTILHADA entre
/// Institution/Customer/Provider/Collaborator/Bank (skill
/// cadastro-entidade-fiscal.md). Contrato de genericidade: recebe [value] +
/// [onChanged] tipados em shared/entity/domain — NUNCA importa módulo.
///
/// Campos de tb_entity + toggle TRIPLO F/J/N (Fase 3 Entidade Única,
/// decisão 4) que alterna tb_person × tb_company × tb_no_doc. Trocar o
/// toggle NÃO apaga o que foi digitado no outro tipo (o draft preserva as
/// fatias; só a do personType atual vai no salvar). No modo 'N' o bloco
/// fiscal desaparece — o external_id é gerado pelo backend (decisão 5).
///
/// PREFILL por documento (decisões 3, 9 e 10): com [prefillEnabled] (só na
/// CRIAÇÃO) e [byDocumentLookup] informados, ao sair do campo CPF/CNPJ com
/// documento VÁLIDO a aba consulta /api/entities/by-document; se a entidade
/// já existe, oferece carregar a cadeia inteira no draft. É só UX — o app
/// nunca envia entityId; a API resolve o reuso dentro da transação.
class EntityMainTab extends StatefulWidget {
  const EntityMainTab({
    required this.value,
    required this.onChanged,
    this.byDocumentLookup,
    this.prefillEnabled = false,
    this.hooks,
    super.key,
  });

  final ObjectEntityFiscal value;
  final ValueChanged<ObjectEntityFiscal> onChanged;

  /// Ganchos de foco/marcação da mecânica uma-pendência do form composto
  /// (R3) — opcionais: sem eles a aba funciona igual, só sem foco dirigido.
  final EntityMainTabHooks? hooks;

  /// Busca por documento para o prefill — bind do módulo consumidor.
  final EntityByDocumentDatasource? byDocumentLookup;

  /// true somente no modo CRIAÇÃO (na edição o conflito de documento é
  /// tratado pela API com 409 — Fase 3, decisão 6).
  final bool prefillEnabled;

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
  late final TextEditingController _externalId;

  /// Evita repetir a consulta/dialog para o mesmo documento.
  String _lastPrefillDoc = '';
  bool _prefillBusy = false;

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
    _externalId   = TextEditingController(text: v.noDoc?.externalId ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCompany, _nickTrade, _aniversary, _cpf, _rg, _birthday,
      _cnpj, _ie, _im, _dtFoundation, _externalId,
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

  /// Validators dos documentos com o MESMO julgamento do salvar (11/14
  /// dígitos) — a marca inline do campo nunca mente para a pendência (R3).
  String? _validateCpf(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'register.required'.tr();
    if (digits.length != 11) return 'forms.entity.cpfInvalid'.tr();
    return null;
  }

  String? _validateCnpj(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'register.required'.tr();
    if (digits.length != 14) return 'forms.entity.cnpjInvalid'.tr();
    return null;
  }

  // -------------------------------------------------------------------
  // Prefill by-document (Fase 3, decisões 3, 9 e 10)
  // -------------------------------------------------------------------

  Future<void> _maybePrefill(String personType) async {
    if (!widget.prefillEnabled || widget.byDocumentLookup == null) return;
    if (_prefillBusy) return;

    final doc = personType == 'F'
        ? (widget.value.person?.cpfDigits ?? '')
        : (widget.value.company?.cnpjDigits ?? '');
    final valid = personType == 'F'
        ? SetesValidators.isValidCpf(doc)
        : SetesValidators.isValidCnpj(doc);
    if (!valid || doc == _lastPrefillDoc) return;

    _prefillBusy = true;
    try {
      final result = await widget.byDocumentLookup!
          .byDocument(personType: personType, doc: doc);
      _lastPrefillDoc = doc;
      if (!mounted || !result.found || result.entity == null) return;
      final load = await _confirmPrefill(result.roles);
      if (load && mounted) _applyPrefill(result.entity!);
    } on Failure {
      // Prefill é só UX — falha silenciosa; a resolução definitiva do
      // documento acontece no salvar (decisão 9).
    } finally {
      _prefillBusy = false;
    }
  }

  /// Decisão TIPADA via ponte (R4): Sim = carregar a cadeia existente;
  /// Cancelar (ou fechar) = seguir digitando do zero. Sem ação alternativa
  /// → sem botão Não.
  Future<bool> _confirmPrefill(List<String> roles) async {
    final roleNames = roles
        .map((r) => trCatalog(r, r, prefix: 'forms.entity.role'))
        .join(', ');
    final decision = await askDecision(
      context,
      title: 'forms.entity.prefillTitle'.tr(),
      message: [
        if (roleNames.isNotEmpty)
          'forms.entity.prefillRoles'.tr(args: [roleNames]),
        'forms.entity.prefillQuestion'.tr(),
      ].join('\n\n'),
      yesLabel: 'forms.entity.prefillLoad'.tr(),
    );
    return decision == SetesDecision.yes;
  }

  /// Aplica a cadeia encontrada no draft e sincroniza os controllers.
  /// O id NÃO entra no draft — o app nunca envia entityId (decisão 9).
  void _applyPrefill(ObjectEntityFiscal found) {
    final updated = widget.value.copyWith(
      nameCompany: found.nameCompany,
      nickTrade:   found.nickTrade,
      aniversary:  () => found.aniversary,
      addresses:   found.addresses,
      phones:      found.phones,
      socialMedia: found.socialMedia,
      personType:  found.personType,
      person:      found.person,
      company:     found.company,
    );

    _nameCompany.text  = updated.nameCompany;
    _nickTrade.text    = updated.nickTrade;
    _aniversary.text   = isoDateToDisplay(updated.aniversary);
    _cpf.text          = updated.person?.cpf ?? '';
    _rg.text           = updated.person?.rg ?? '';
    _birthday.text     = isoDateToDisplay(updated.person?.birthday);
    _cnpj.text         = updated.company?.cnpj ?? '';
    _ie.text           = updated.company?.ie ?? '';
    _im.text           = updated.company?.im ?? '';
    _dtFoundation.text = isoDateToDisplay(updated.company?.dtFoundation);

    _emit(updated);
  }

  /// Dispara o prefill quando o foco SAI do campo de documento.
  Widget _docBlurListener({required String personType, required Widget child}) =>
      Focus(
        skipTraversal: true,
        canRequestFocus: false,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _maybePrefill(personType);
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final personType = widget.value.personType;

    // Semântica dos rótulos por tipo (decisão do Valdo, 2026-07-18):
    // PJ = Razão Social / Nome Fantasia; PF e Sem Documento = Nome
    // Completo / Apelido. Por isso o toggle F/J/N vem PRIMEIRO — ele
    // redefine os campos abaixo. UMA data só por tipo: PF = Data de
    // Nascimento (person), PJ = Data de Fundação (company), Sem Documento =
    // Aniversário (entity) — o aniversary da entity só aparece no modo 'N'.
    final isCompany = personType == 'J';

    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis, na ordem declarada; toggle F/J/N fica fora da sequência.
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
            // Toggle F/J/N PRIMEIRO (fora da sequência de Tab) — Fase 3,
            // decisão 4 + semântica dos rótulos (2026-07-18).
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
                      ButtonSegment(
                          value: 'N',
                          label: SetesText('forms.entity.personN'.tr())),
                    ],
                    selected: {personType},
                    onSelectionChanged: (selection) => _emit(
                        widget.value.copyWith(personType: selection.first)),
                  ),
                ),
              ),
            ),
            field(SetesTextField(
              label: (isCompany
                      ? 'forms.entity.nameCompany'
                      : 'forms.entity.nameCompanyPerson')
                  .tr(),
              controller: _nameCompany,
              focusNode: widget.hooks?.nameCompanyFocus,
              fieldKey: widget.hooks?.nameCompanyKey,
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: _validateRequired,
              onChanged: (t) => _emit(widget.value.copyWith(nameCompany: t)),
            )),
            field(SetesTextField(
              label: (isCompany
                      ? 'forms.entity.nickTrade'
                      : 'forms.entity.nickTradePerson')
                  .tr(),
              controller: _nickTrade,
              focusNode: widget.hooks?.nickTradeFocus,
              fieldKey: widget.hooks?.nickTradeKey,
              textInputAction: TextInputAction.next,
              validator: _validateRequired,
              onChanged: (t) => _emit(widget.value.copyWith(nickTrade: t)),
            )),
            // Aniversário (tb_entity) SÓ no modo Sem Documento — PF usa a
            // Data de Nascimento (person) e PJ a Data de Fundação (company).
            if (personType == 'N')
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
            if (personType == 'F') ...[
              field(_docBlurListener(
                personType: 'F',
                child: SetesTextField(
                  label: 'forms.entity.cpf'.tr(),
                  controller: _cpf,
                  focusNode: widget.hooks?.cpfFocus,
                  fieldKey: widget.hooks?.cpfKey,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: _validateCpf,
                  onChanged: (t) => _emit(widget.value
                      .copyWith(person: _person.copyWith(cpf: t.trim()))),
                ),
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
            ] else if (personType == 'J') ...[
              field(_docBlurListener(
                personType: 'J',
                child: SetesTextField(
                  label: 'forms.entity.cnpj'.tr(),
                  controller: _cnpj,
                  focusNode: widget.hooks?.cnpjFocus,
                  fieldKey: widget.hooks?.cnpjKey,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: _validateCnpj,
                  onChanged: (t) => _emit(widget.value
                      .copyWith(company: _company.copyWith(cnpj: t.trim()))),
                ),
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
            ] else ...[
              // 'N' — Sem documento: bloco fiscal oculto; o identificador
              // externo é gerado pelo backend (leitura na edição).
              if (_externalId.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SetesTextField(
                    label: 'forms.entity.externalId'.tr(),
                    controller: _externalId,
                    readOnly: true,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
