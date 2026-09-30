import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/address_list_tab.dart';
import '../../../../shared/entity/widgets/phone_list_tab.dart';
import '../../../../shared/entity/widgets/social_media_list_tab.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../data/datasource/establishment_issuer_datasource.dart';
import '../../domain/entity/object_establishment.dart';
import '../bloc/establishment_bloc.dart';
import '../widget/establishment_issuer_section.dart';

/// Tela "Meu Estabelecimento" — interface 'establishment', menu Sistema.
///
/// NÃO é RegisterSearchPage + RegisterFormPage: é um CRUD comum SEM lista
/// (parecer setes-conceito 2026-08-25) — a API garante cardinalidade 1 pelo
/// token (institutionId implícito, sem `:id` em lugar nenhum); o bloc
/// carrega o registro direto no initState (molde de carregamento do
/// CashierBloc, sem a máquina de estados de sessão dele).
///
/// Abas reaproveitadas de app/shared/entity/widgets (mesmas do form de
/// `institutions`): Endereços/Fones/Redes Sociais. A aba Principal é
/// PRÓPRIA (subconjunto restrito de campos — decisão fechada com o
/// usuário): documento e tipo de pessoa são SOMENTE EXIBIÇÃO. A 5ª aba
/// "Emissor fiscal" (Onda 3) é uma SEÇÃO AUTÔNOMA com datasource próprio —
/// o check do shell não a salva (ela tem os próprios botões).
class EstablishmentPage extends StatefulWidget {
  const EstablishmentPage({required this.title, super.key});

  /// Nome da interface no menu ("Meu Estabelecimento") via trCatalog.
  final String title;

  @override
  State<EstablishmentPage> createState() => _EstablishmentPageState();
}

class _EstablishmentPageState extends State<EstablishmentPage> {
  late final EstablishmentBloc _bloc;
  late final CountryLookupDatasource _countryLookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;
  late final EstablishmentIssuerDatasource _issuerDatasource;

  /// Ancora o fields[] do servidor no campo certo (showServerFieldError).
  final _formViewKey = GlobalKey<_EstablishmentFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<EstablishmentBloc>()
      ..add(const EstablishmentStarted());
    _countryLookup = Modular.get<CountryLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup = Modular.get<CityLookupDatasource>();
    _issuerDatasource = Modular.get<EstablishmentIssuerDatasource>();
  }

  /// Sem lista para voltar — "voltar" sai da tela para a Home (mesmo botão
  /// do contrato visual, sem equivalente de pesquisa aqui).
  void _back() => Modular.to.navigate('/home/welcome/');

  Widget _buildError(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              SetesText('forms.establishment.loadError'.tr()),
              const SizedBox(height: 24),
              SetesButton(
                label: 'register.retry'.tr(),
                icon: Icons.refresh,
                onPressed: () =>
                    _bloc.add(const EstablishmentStarted()),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<EstablishmentBloc, EstablishmentState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is EstablishmentActionSuccess ||
            current is EstablishmentActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar (R1); falha =
        // dialog, com fields[] do servidor ancorado no campo quando o form
        // está montado.
        listener: (context, state) {
          if (state is EstablishmentActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as EstablishmentActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) => current is EstablishmentPanelState,
        builder: (context, state) {
          final panel = state is EstablishmentPanelState
              ? state
              : const EstablishmentPanelState(loading: true);
          if (panel.loading) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: const SetesCircularProgressIndicator(),
            );
          }
          final draft = panel.draft;
          if (draft == null) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: _buildError(context),
            );
          }
          return _EstablishmentFormView(
            key: _formViewKey,
            title: widget.title,
            draft: draft,
            saving: panel.saving,
            countryLookup: _countryLookup,
            stateLookup: _stateLookup,
            cityLookup: _cityLookup,
            issuerDatasource: _issuerDatasource,
            onDraftChanged: (d) => _bloc.add(EstablishmentDraftChanged(d)),
            onSave: () => _bloc.add(EstablishmentSaveRequested(draft)),
            onBack: _back,
          );
        },
      );
}

/// Form artesanal com SetesFormShell + abas (grupos naturais —
/// criar-formulario-cadastro.md item 2): Principal / Endereços / Fones /
/// Redes Sociais. O estado do form é o DRAFT do bloc; este widget só
/// repassa fatias editadas (apresentação pura).
class _EstablishmentFormView extends StatefulWidget {
  const _EstablishmentFormView({
    required this.title,
    required this.draft,
    required this.saving,
    required this.countryLookup,
    required this.stateLookup,
    required this.cityLookup,
    required this.issuerDatasource,
    required this.onDraftChanged,
    required this.onSave,
    required this.onBack,
    super.key,
  });

  final String title;
  final ObjectEstablishment draft;
  final bool saving;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;
  final EstablishmentIssuerDatasource issuerDatasource;
  final ValueChanged<ObjectEstablishment> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  State<_EstablishmentFormView> createState() =>
      _EstablishmentFormViewState();
}

class _EstablishmentFormViewState extends State<_EstablishmentFormView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  /// Opção "não informado" dos dropdowns de regime — o draft guarda '' e
  /// o toJson manda null (limpa na API).
  static const _notSet = '';

  /// Rótulos canônicos de TAX_REGIMES da API (D39) — catálogo, não se traduz.
  static const _taxRegimes = [
    '1 - Simples Nacional',
    '2 - Simples Nacional - excesso de sublimite de receita bruta',
    '3 - Regime Normal - Lucro Real',
    '3 - Regime Normal - Lucro Presumido',
  ];

  /// Regime carregado do servidor — referência do aviso D42 (a troca de
  /// GRUPO em relação ao que está GRAVADO é o que dispara a remoção no save).
  String? _originalRegime;

  /// Recria o Dropdown quando o usuário CANCELA o aviso (FormField retém a
  /// seleção internamente — trocar a key devolve o valor do draft).
  int _regimeEpoch = 0;

  /// Grupo do CRT pelo 1º caractere do rótulo: Simples (1/2) × Normal (3).
  String? _crtGroupOf(String? regime) {
    final first = (regime ?? '').trim().isEmpty ? '' : regime!.trim()[0];
    if (first == '1' || first == '2') return 'simples';
    if (first == '3') return 'normal';
    return null;
  }

  /// D42 — troca de grupo do regime é CONTROLADA: aviso de que o save
  /// removerá o código do regime antigo (CST indo p/ Simples; CSOSN indo p/
  /// Normal) das regras de tributação, exigindo revisão. Cancelar reverte.
  Future<void> _onRegimeSelected(String? sel) async {
    if (sel == null) return;
    final newGroup = _crtGroupOf(sel);
    final oldGroup = _crtGroupOf(_originalRegime);
    if (newGroup != null && newGroup != oldGroup) {
      final removed = newGroup == 'simples' ? 'CST' : 'CSOSN';
      final decision = await askDecision(
        context,
        title: 'forms.establishment.taxRegimeChangeTitle'.tr(),
        message: 'forms.establishment.taxRegimeChangeWarning'
            .tr(namedArgs: {'code': removed}),
      );
      if (!mounted) return;
      if (decision != SetesDecision.yes) {
        setState(() => _regimeEpoch++);
        return;
      }
    }
    widget.onDraftChanged(widget.draft.copyWith(taxRegime: sel));
  }

  final _nameCompanyFocus = FocusNode();
  final _nickTradeFocus = FocusNode();
  final _cnaeFocus = FocusNode();
  final _aliquotFocus = FocusNode();
  final _nameCompanyKey = GlobalKey<FormFieldState<String>>();
  final _nickTradeKey = GlobalKey<FormFieldState<String>>();
  final _cnaeKey = GlobalKey<FormFieldState<String>>();
  final _aliquotKey = GlobalKey<FormFieldState<String>>();

  late final TextEditingController _nameCompany;
  late final TextEditingController _nickTrade;
  late final TextEditingController _document;
  late final TextEditingController _ie;
  late final TextEditingController _im;
  late final TextEditingController _cnae;
  late final TextEditingController _aliquot;

  @override
  void initState() {
    super.initState();
    _originalRegime = widget.draft.taxRegime;
    _nameCompany = TextEditingController(text: widget.draft.nameCompany);
    _nickTrade   = TextEditingController(text: widget.draft.nickTrade);
    _document    = TextEditingController(text: widget.draft.document);
    _ie          = TextEditingController(text: widget.draft.ie ?? '');
    _im          = TextEditingController(text: widget.draft.im ?? '');
    _cnae        = TextEditingController(text: widget.draft.cnae ?? '');
    _aliquot     = TextEditingController(
        text: widget.draft.simplesTotalTaxAliquot ?? '');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCompanyFocus.dispose();
    _nickTradeFocus.dispose();
    _cnaeFocus.dispose();
    _aliquotFocus.dispose();
    for (final c in [
      _nameCompany, _nickTrade, _document, _ie, _im, _cnae, _aliquot,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ObjectEstablishment get _draft => widget.draft;

  /// CNAE: opcional; quando informado, exatamente 7 dígitos (DTO da API).
  String? _validateCnae(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return RegExp(r'^\d{7}$').hasMatch(text)
        ? null
        : 'forms.establishment.cnaeInvalid'.tr();
  }

  /// Q-N37: % aproximado da alíquota efetiva do Simples (pTotTribSN) —
  /// obrigatório para ME/EPP; > 0, até 99,99, no máximo 2 casas (DTO da API).
  String? _validateAliquot(String? value) {
    if (_draft.simplesRegime != '3') return null;
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'register.requiredField'
          .tr(args: ['forms.establishment.simplesTotalTaxAliquot'.tr()]);
    }
    final v = ObjectEstablishment.parseAliquot(text);
    final twoDecimals = RegExp(r'^\d{1,2}([.,]\d{1,2})?$').hasMatch(text);
    return v == null || !twoDecimals || v <= 0 || v > 99.99
        ? 'forms.establishment.simplesTotalTaxAliquotInvalid'.tr()
        : null;
  }

  /// Valor do dropdown: código fora do catálogo (dado legado) cai em
  /// "não informado".
  String _dropdownValue(String? code, List<String> catalog) =>
      code != null && catalog.contains(code) ? code : _notSet;

  /// Campos NA ORDEM da tela (R3) — uma pendência por vez, foco na aba
  /// Principal (a única com campos obrigatórios). Names casam com o
  /// payload do PUT — por eles o fields[] do servidor ancora no campo.
  List<PendencyField> get _pendencyFields {
    void toMainTab() => _tabs.animateTo(0);
    return [
      PendencyField(
        name: 'nameCompany',
        beforeFocus: toMainTab,
        focusNode: _nameCompanyFocus,
        fieldKey: _nameCompanyKey,
        validate: () => _draft.nameCompany.trim().isEmpty
            ? 'register.requiredField'
                .tr(args: ['forms.establishment.nameCompany'.tr()])
            : null,
      ),
      PendencyField(
        name: 'nickTrade',
        beforeFocus: toMainTab,
        focusNode: _nickTradeFocus,
        fieldKey: _nickTradeKey,
        validate: () => _draft.nickTrade.trim().isEmpty
            ? 'register.requiredField'
                .tr(args: ['forms.establishment.nickTrade'.tr()])
            : null,
      ),
      PendencyField(
        name: 'cnae',
        beforeFocus: toMainTab,
        focusNode: _cnaeFocus,
        fieldKey: _cnaeKey,
        validate: () => _validateCnae(_draft.cnae),
      ),
      // Só âncora do fields[] do servidor (dropdowns não têm foco de texto).
      PendencyField(
        name: 'simplesRegime',
        beforeFocus: toMainTab,
        validate: () => null,
      ),
      // Q-N36: ME/EPP EXIGE a apuração (o fisco recusa a ausência — E0166);
      // espelho da mesma regra da API (422 no mesmo campo).
      PendencyField(
        name: 'simplesAssessment',
        beforeFocus: toMainTab,
        validate: () => _draft.simplesRegime == '3' &&
                !ObjectEstablishment.simplesAssessments
                    .contains(_draft.simplesAssessment)
            ? 'register.requiredField'
                .tr(args: ['forms.establishment.simplesAssessment'.tr()])
            : null,
      ),
      PendencyField(
        name: 'simplesTotalTaxAliquot',
        beforeFocus: toMainTab,
        focusNode: _aliquotFocus,
        fieldKey: _aliquotKey,
        validate: () => _validateAliquot(_draft.simplesTotalTaxAliquot),
      ),
      PendencyField(
        name: 'specialTaxRegime',
        beforeFocus: toMainTab,
        validate: () => null,
      ),
    ];
  }

  /// Ancora o fields[] do envelope 400/409 no campo (chamado pelo listener
  /// do bloc via GlobalKey).
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(context, failure, _pendencyFields);

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final isCompany = draft.personType == 'J';
    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onBack,
      onSave: _save,
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'register.tabMain'.tr()),
              Tab(text: 'register.tabAddresses'.tr()),
              Tab(text: 'register.tabPhones'.tr()),
              Tab(text: 'register.tabSocialMedia'.tr()),
              Tab(text: 'forms.establishment.issuerTab'.tr()),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(0),
                        child: SetesTextField(
                          label: 'forms.establishment.nameCompany'.tr(),
                          controller: _nameCompany,
                          focusNode: _nameCompanyFocus,
                          fieldKey: _nameCompanyKey,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          validator: (_) =>
                              _draft.nameCompany.trim().isEmpty
                                  ? 'register.required'.tr()
                                  : null,
                          onChanged: (t) => widget
                              .onDraftChanged(draft.copyWith(nameCompany: t)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: SetesTextField(
                          label: 'forms.establishment.nickTrade'.tr(),
                          controller: _nickTrade,
                          focusNode: _nickTradeFocus,
                          fieldKey: _nickTradeKey,
                          textInputAction: TextInputAction.next,
                          validator: (_) => _draft.nickTrade.trim().isEmpty
                              ? 'register.required'.tr()
                              : null,
                          onChanged: (t) => widget
                              .onDraftChanged(draft.copyWith(nickTrade: t)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Documento e tipo de pessoa: SOMENTE EXIBIÇÃO (a
                      // API não aceita alteração aqui) — fora do Tab.
                      ExcludeFocusTraversal(
                        child: SetesTextField(
                          label: isCompany
                              ? 'forms.establishment.cnpj'.tr()
                              : 'forms.establishment.cpf'.tr(),
                          controller: _document,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: SetesTextField(
                          label: 'forms.establishment.ie'.tr(),
                          controller: _ie,
                          textInputAction: TextInputAction.next,
                          onChanged: (t) => widget.onDraftChanged(
                              draft.copyWith(ie: t)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: SetesTextField(
                          label: 'forms.establishment.im'.tr(),
                          controller: _im,
                          textInputAction: TextInputAction.next,
                          onChanged: (t) => widget.onDraftChanged(
                              draft.copyWith(im: t)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Regime tributário (D39 — campo avulso, mantido SÓ
                      // aqui): rótulos canônicos da API (não se traduzem);
                      // dirige o despacho CST × CSOSN do motor e a
                      // adaptação do form de Regras de Tributação.
                      SetesDropdown<String>(
                        key: ValueKey('taxRegime$_regimeEpoch'),
                        label: 'forms.establishment.taxRegime'.tr(),
                        // Valor fora do catálogo (dado legado) não pode
                        // chegar ao Dropdown — cai para "não selecionado".
                        value: _taxRegimes.contains(draft.taxRegime)
                            ? draft.taxRegime
                            : null,
                        items: _taxRegimes,
                        onChanged: _onRegimeSelected,
                      ),
                      const SizedBox(height: 16),
                      // Fatos do EMITENTE da NFS-e (Onda 3 — §9.3 da
                      // prompt_onda_nfe_sefaz.md): opSimpNac, regEspTrib e
                      // CNAE viajam no PUT como o taxRegime (null = limpa).
                      SetesDropdown<String>(
                        label: 'forms.establishment.simplesRegime'.tr(),
                        value: _dropdownValue(draft.simplesRegime,
                            ObjectEstablishment.simplesRegimes),
                        items: const [
                          _notSet,
                          ...ObjectEstablishment.simplesRegimes,
                        ],
                        itemLabel: (v) => v == _notSet
                            ? 'forms.establishment.regimeNotSet'.tr()
                            : 'forms.establishment.simplesRegime$v'.tr(),
                        onChanged: (v) => widget.onDraftChanged(
                            draft.copyWith(simplesRegime: v ?? _notSet)),
                      ),
                      const SizedBox(height: 16),
                      // D-N19a/Q-N36: o ME/EPP (3) informa SEMPRE em que regime
                      // apura (regApTribSN) — obrigatório no DPS (E0166 do
                      // fisco); "não informado" só como estado a corrigir.
                      if (draft.simplesRegime == '3') ...[
                        SetesDropdown<String>(
                          label: 'forms.establishment.simplesAssessment'.tr(),
                          value: _dropdownValue(draft.simplesAssessment,
                              ObjectEstablishment.simplesAssessments),
                          items: const [
                            _notSet,
                            ...ObjectEstablishment.simplesAssessments,
                          ],
                          itemLabel: (v) => v == _notSet
                              ? 'forms.establishment.regimeNotSet'.tr()
                              : 'forms.establishment.simplesAssessment$v'.tr(),
                          onChanged: (v) => widget.onDraftChanged(
                              draft.copyWith(simplesAssessment: v ?? _notSet)),
                        ),
                        const SizedBox(height: 16),
                        // Q-N37: total aproximado de tributos da NFS-e do
                        // ME/EPP = alíquota efetiva do DAS (o contador informa).
                        SetesTextField(
                          label:
                              'forms.establishment.simplesTotalTaxAliquot'.tr(),
                          hint: 'forms.establishment.simplesTotalTaxAliquotHint'
                              .tr(),
                          controller: _aliquot,
                          focusNode: _aliquotFocus,
                          fieldKey: _aliquotKey,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: _validateAliquot,
                          onChanged: (t) => widget.onDraftChanged(
                              draft.copyWith(simplesTotalTaxAliquot: t)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SetesDropdown<String>(
                        label: 'forms.establishment.specialTaxRegime'.tr(),
                        value: _dropdownValue(draft.specialTaxRegime,
                            ObjectEstablishment.specialTaxRegimes),
                        items: const [
                          _notSet,
                          ...ObjectEstablishment.specialTaxRegimes,
                        ],
                        itemLabel: (v) => v == _notSet
                            ? 'forms.establishment.regimeNotSet'.tr()
                            : 'forms.establishment.specialTaxRegime$v'.tr(),
                        onChanged: (v) => widget.onDraftChanged(
                            draft.copyWith(specialTaxRegime: v ?? _notSet)),
                      ),
                      const SizedBox(height: 16),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(4),
                        child: SetesTextField(
                          label: 'forms.establishment.cnae'.tr(),
                          controller: _cnae,
                          focusNode: _cnaeFocus,
                          fieldKey: _cnaeKey,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          validator: _validateCnae,
                          onChanged: (t) => widget.onDraftChanged(
                              draft.copyWith(cnae: t)),
                        ),
                      ),
                    ],
                  ),
                ),
                AddressListTab(
                  items: draft.addresses,
                  countryLookup: widget.countryLookup,
                  stateLookup: widget.stateLookup,
                  cityLookup: widget.cityLookup,
                  onChanged: (list) =>
                      widget.onDraftChanged(draft.copyWith(addresses: list)),
                ),
                PhoneListTab(
                  items: draft.phones,
                  onChanged: (list) =>
                      widget.onDraftChanged(draft.copyWith(phones: list)),
                ),
                SocialMediaListTab(
                  items: draft.socialMedia,
                  onChanged: (list) => widget
                      .onDraftChanged(draft.copyWith(socialMedia: list)),
                ),
                // Emissor fiscal: seção autônoma (datasource próprio, botões
                // próprios) — não participa do draft nem do check do shell.
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    EstablishmentIssuerSection(
                        datasource: widget.issuerDatasource),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
